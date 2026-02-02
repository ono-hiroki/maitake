# AWSネットワーク入門 - VPCをTerraformで構築してWebサーバーを公開する

AWSでインフラを構築するとき、最初に理解すべきなのがネットワークです。
この記事では、VPCの作成からEC2でのWebサーバー公開まで、Terraformでひとつずつリソースを作りながらAWSネットワークの基本を学びます。

[AWS Hands-on for Beginners Network編#1](https://pages.awscloud.com/JAPAN-event-OE-Hands-on-for-Beginners-Network1-2022-confirmation_945.html) の内容をベースにしていますが、NATゲートウェイは扱わず、パブリックサブネットのみの構成で進めます。

## 最終構成

最終的に以下の構成を作ります。

```
Internet
  │
  ├── Internet Gateway
  │
VPC (10.0.0.0/16)
  │
  ├── Public Subnet (10.0.1.0/24) - ap-northeast-1a
  │     └── EC2 (Webサーバー)
  │
  └── Public Subnet (10.0.2.0/24) - ap-northeast-1c
```

EC2上にApacheをインストールし、ブラウザからアクセスできることをゴールとします。

## 前提

- AWSアカウントがあること
- Terraform CLIがインストールされていること
- AWS CLIで認証情報が設定されていること

## 1. VPCを作成する

### VPCとは

VPC（Virtual Private Cloud）は、AWS上に作る自分専用の仮想ネットワークです。
AWSの多くのリソース（EC2、RDS、ECSなど）はVPCの中に配置します。VPCを作ることで、他のAWSアカウントのネットワークとは完全に分離された空間が手に入ります。

### CIDRブロック

VPCを作成するときに「このVPCが使えるIPアドレスの範囲」をCIDRブロックで指定します。

`10.0.0.0/16` は `10.0.0.0` ～ `10.0.255.255` の範囲（65,536個のIPアドレス）を意味します。`/16` の数字が小さいほど範囲が広くなります。

| CIDR | IPアドレス数 | 範囲 |
|------|------------|------|
| 10.0.0.0/16 | 65,536 | 10.0.0.0 ~ 10.0.255.255 |
| 10.0.0.0/24 | 256 | 10.0.0.0 ~ 10.0.0.255 |

### Terraformで作成

```hcl
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "network-basics-vpc"
  }
}
```

`enable_dns_support` と `enable_dns_hostnames` を有効にすると、VPC内のリソースにDNSホスト名が割り当てられます。後でEC2にパブリックDNSでアクセスしたい場合に必要になるので、有効にしておきます。

この時点では、VPCは外部と一切通信できない閉じたネットワークです。

### AWS CLIで確認する

```bash
aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=network-basics-vpc" \
  --query "Vpcs[0].{VpcId:VpcId,CidrBlock:CidrBlock,State:State}" \
  --output table
```

```
-----------------------------------------
|             DescribeVpcs              |
+-----------+--------------+------------+
| CidrBlock |    State     |   VpcId    |
+-----------+--------------+------------+
| 10.0.0.0/16 | available | vpc-xxxxxxx |
+-----------+--------------+------------+
```

VPCが `available` 状態で作成され、CIDRブロック `10.0.0.0/16` が割り当てられていることが確認できます。

## 2. インターネットゲートウェイを作成する

### インターネットゲートウェイとは

インターネットゲートウェイ（IGW）は、VPCとインターネットの間の出入り口です。
VPCにIGWをアタッチすることで、VPC内のリソースがインターネットと通信できるようになります。

```
Internet ←→ Internet Gateway ←→ VPC
```

ただし、IGWをアタッチしただけではまだ通信できません。「どのサブネットの通信をIGWに向けるか」をルートテーブルで設定する必要があります（後述）。

### Terraformで作成

```hcl
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "network-basics-igw"
  }
}
```

`vpc_id` を指定することで、VPCへのアタッチも同時に行われます。

### AWS CLIで確認する

```bash
aws ec2 describe-internet-gateways \
  --filters "Name=tag:Name,Values=network-basics-igw" \
  --query "InternetGateways[0].{InternetGatewayId:InternetGatewayId,VpcId:Attachments[0].VpcId,State:Attachments[0].State}" \
  --output table
```

```
------------------------------------------------------
|           DescribeInternetGateways                 |
+-------------------+----------+---------------------+
| InternetGatewayId |  State   |       VpcId         |
+-------------------+----------+---------------------+
| igw-xxxxxxx       | attached | vpc-xxxxxxx         |
+-------------------+----------+---------------------+
```

State が `attached` になっていれば、VPCにアタッチされています。

## 3. サブネットを作成する

### サブネットとは

サブネットは、VPCのIPアドレス範囲をさらに小さく分割したものです。
EC2やRDSなどのリソースは、VPCに直接ではなくサブネットに配置します。

サブネットは必ず1つのアベイラビリティゾーン（AZ）に属します。複数のAZにサブネットを作ることで、1つのAZに障害が起きても別のAZで処理を継続できます。

### パブリックサブネットとプライベートサブネット

| 種類 | 特徴 |
|------|------|
| パブリックサブネット | インターネットと直接通信できる。ルートテーブルでIGWへのルートを持つ |
| プライベートサブネット | インターネットから直接アクセスできない。外部通信にはNATゲートウェイが必要 |

今回はパブリックサブネットのみ作成します。

### CIDR設計

VPC `10.0.0.0/16` の中から、サブネットごとにCIDRを切り出します。

| サブネット | CIDR | AZ | IPアドレス数 |
|-----------|------|-----|------------|
| public-a | 10.0.1.0/24 | ap-northeast-1a | 251（AWS予約5個を除く） |
| public-c | 10.0.2.0/24 | ap-northeast-1c | 251 |

AWSでは各サブネットの先頭4個と末尾1個のIPアドレスが予約されるため、`/24`（256個）のサブネットで実際に使えるのは251個です。

### Terraformで作成

```hcl
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "network-basics-public-a"
  }
}

resource "aws_subnet" "public_c" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-northeast-1c"
  map_public_ip_on_launch = true
  tags = {
    Name = "network-basics-public-c"
  }
}
```

`map_public_ip_on_launch = true` を設定すると、このサブネットに起動したEC2に自動でパブリックIPが割り当てられます。パブリックサブネットでは通常これを有効にします。

### AWS CLIで確認する

```bash
aws ec2 describe-subnets \
  --filters "Name=tag:Name,Values=network-basics-public-*" \
  --query "Subnets[].{Name:Tags[?Key=='Name']|[0].Value,SubnetId:SubnetId,CidrBlock:CidrBlock,AZ:AvailabilityZone,MapPublicIp:MapPublicIpOnLaunch}" \
  --output table
```

```
-----------------------------------------------------------------------------------------
|                                    DescribeSubnets                                    |
+------------------+-----------+-------------------------+--------------+----------------+
|        AZ        | CidrBlock |       MapPublicIp       |     Name     |   SubnetId     |
+------------------+-----------+-------------------------+--------------+----------------+
| ap-northeast-1a  | 10.0.1.0/24 | True                 | network-basics-public-a | subnet-xxx |
| ap-northeast-1c  | 10.0.2.0/24 | True                 | network-basics-public-c | subnet-xxx |
+------------------+-----------+-------------------------+--------------+----------------+
```

2つのサブネットが異なるAZに作成され、`MapPublicIp` が `True` になっていることが確認できます。

## 4. ルートテーブルを設定する

### ルートテーブルとは

ルートテーブルは、サブネット内のリソースから送信されるトラフィックの宛先を制御するものです。「この宛先のパケットはここに送る」というルールの集まりです。

VPCを作成すると、自動的に**メインルートテーブル**が作られます。メインルートテーブルには以下のローカルルートが含まれています。

| 送信先 | ターゲット |
|--------|----------|
| 10.0.0.0/16 | local |

これは「VPC内（10.0.0.0/16）宛の通信はVPC内部で処理する」という意味です。このルートは削除できません。

### パブリックサブネットのルーティング

パブリックサブネットからインターネットに出るためには、「VPC外への通信はIGWに送る」というルートを追加します。

| 送信先 | ターゲット |
|--------|----------|
| 10.0.0.0/16 | local |
| 0.0.0.0/0 | Internet Gateway |

`0.0.0.0/0` はすべてのIPアドレスを意味します。ルートテーブルは最も具体的な（範囲が狭い）ルートが優先されるので、VPC内の通信は `10.0.0.0/16 → local` が、それ以外の通信は `0.0.0.0/0 → IGW` が使われます。

### Terraformで作成

```hcl
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "network-basics-public-rt"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_c" {
  subnet_id      = aws_subnet.public_c.id
  route_table_id = aws_route_table.public.id
}
```

`aws_route_table` でルートテーブルを作成し、`aws_route_table_association` でサブネットに紐づけます。ローカルルート（10.0.0.0/16 → local）はAWSが自動で追加するため、Terraform側で書く必要はありません。

### AWS CLIで確認する

```bash
aws ec2 describe-route-tables \
  --filters "Name=tag:Name,Values=network-basics-public-rt" \
  --query "RouteTables[0].Routes[].{Destination:DestinationCidrBlock,Target:GatewayId}" \
  --output table
```

```
-------------------------------------
|        DescribeRouteTables        |
+-----------------+-----------------+
|   Destination   |     Target      |
+-----------------+-----------------+
|  10.0.0.0/16    |  local          |
|  0.0.0.0/0      |  igw-xxxxxxx    |
+-----------------+-----------------+
```

ローカルルート（VPC内通信）とIGWへのルート（インターネット向け通信）の2つが設定されています。Terraformで定義したのは `0.0.0.0/0 → IGW` のみですが、`10.0.0.0/16 → local` がAWSによって自動で追加されていることがわかります。

紐づけられているサブネットも確認します。

```bash
aws ec2 describe-route-tables \
  --filters "Name=tag:Name,Values=network-basics-public-rt" \
  --query "RouteTables[0].Associations[].SubnetId" \
  --output table
```

```
-----------------------
| DescribeRouteTables |
+---------------------+
|  subnet-xxxxxxx     |
|  subnet-xxxxxxx     |
+---------------------+
```

2つのパブリックサブネットが紐づいていれば正しい構成です。

## 5. EC2を起動して動作確認する

ネットワークが構築できたので、EC2インスタンスを配置してWebサーバーを公開します。

### セキュリティグループ

セキュリティグループはEC2に対するファイアウォールです。許可するトラフィックをインバウンド（受信）とアウトバウンド（送信）で定義します。

今回はHTTP（80番ポート）のインバウンドを全IPから許可し、アウトバウンドはすべて許可します。

```hcl
resource "aws_security_group" "web" {
  name   = "network-basics-web-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "network-basics-web-sg"
  }
}
```

### EC2インスタンス

Amazon Linux 2023のAMIを動的に取得し、User Dataでapacheをインストールします。

```hcl
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_a.id
  vpc_security_group_ids = [aws_security_group.web.id]

  user_data = <<-EOF
    #!/bin/bash
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "Hello from network-basics" > /var/www/html/index.html
  EOF

  tags = {
    Name = "network-basics-web"
  }
}
```

User Dataはインスタンスの初回起動時に実行されるスクリプトです。ここでApacheのインストールと起動を行っています。

### デプロイと動作確認

```bash
terraform init
terraform apply
```

### AWS CLIで確認する

EC2インスタンスの状態を確認します。

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=network-basics-web" "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].{InstanceId:InstanceId,State:State.Name,PublicIp:PublicIpAddress,SubnetId:SubnetId,SecurityGroups:SecurityGroups[].GroupName}" \
  --output table
```

```
-------------------------------------------------------------------------
|                         DescribeInstances                             |
+-------------+-----------------+----------+------------+--------------+
| InstanceId  |    PublicIp     |  State   |  SubnetId  | SecurityGroups|
+-------------+-----------------+----------+------------+--------------+
| i-xxxxxxx   | 13.xxx.xxx.xxx | running  | subnet-xxx | network-basics-web-sg |
+-------------+-----------------+----------+------------+--------------+
```

`PublicIp` が割り当てられていることを確認したら、curlでアクセスします。

```bash
curl http://$(terraform output -raw ec2_public_ip)
# => Hello from network-basics
```

「Hello from network-basics」が表示されれば成功です。

### 通信の流れを整理する

ブラウザからEC2にアクセスしたとき、パケットは以下の経路を通ります。

```
ブラウザ
  → Internet
    → Internet Gateway
      → ルートテーブル（10.0.1.0/24 はこのサブネット）
        → セキュリティグループ（80番ポート許可）
          → EC2 (Apache)
```

レスポンスは逆の経路を辿って返ります。作成したすべてのリソースがこの一連の通信に関わっていることがわかります。

## 6. プライベートサブネットにEC2を置いてアクセスできないことを確認する

パブリックサブネットではインターネットからアクセスできることを確認しました。次に、プライベートサブネットに同じEC2を配置して、インターネットからアクセス**できない**ことを確認します。

### プライベートサブネットを作成する

```hcl
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = "ap-northeast-1a"
  tags = {
    Name = "network-basics-private-a"
  }
}
```

パブリックサブネットとの違いは2つです。

| 設定 | パブリック | プライベート |
|------|----------|------------|
| `map_public_ip_on_launch` | `true` | 設定しない（デフォルト`false`） |
| ルートテーブル | IGWへのルートあり | IGWへのルートなし（メインルートテーブルのみ） |

プライベートサブネットにはカスタムルートテーブルを紐づけません。VPC作成時に自動生成されるメインルートテーブル（`10.0.0.0/16 → local` のみ）が使われるため、インターネットへの経路が存在しません。

### プライベートサブネットにEC2を配置する

```hcl
resource "aws_instance" "web_private" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private_a.id
  vpc_security_group_ids = [aws_security_group.web.id]

  user_data = <<-EOF
    #!/bin/bash
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "Hello from private subnet" > /var/www/html/index.html
  EOF

  tags = {
    Name = "network-basics-web-private"
  }
}
```

### AWS CLIで確認する

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=network-basics-web-private" "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].{InstanceId:InstanceId,State:State.Name,PublicIp:PublicIpAddress,PrivateIp:PrivateIpAddress,SubnetId:SubnetId}" \
  --output table
```

```
--------------------------------------------------------------
|                     DescribeInstances                      |
+-------------+---------------+----------+------+------------+
| InstanceId  |   PrivateIp   | PublicIp | State|  SubnetId  |
+-------------+---------------+----------+------+------------+
| i-xxxxxxx   | 10.0.10.xxx   | None     |running| subnet-xxx|
+-------------+---------------+----------+------+------------+
```

`PublicIp` が `None` になっています。`map_public_ip_on_launch` を設定していないため、パブリックIPが割り当てられません。

curlでアクセスを試みても、タイムアウトします。

```bash
curl --connect-timeout 5 http://10.0.10.xxx
# => curl: (28) Connection timed out
```

プライベートサブネットのEC2はインターネットからアクセスできないことが確認できました。これがパブリックサブネットとプライベートサブネットの違いです。

### なぜアクセスできないのか

パブリックIPが割り当てられていないため、そもそもインターネットからの到達先がありません。

では、パブリックIPを付けたらどうなるでしょうか？

### パブリックIPを付けてもアクセスできないことを確認する

EC2に `associate_public_ip_address = true` を追加して、プライベートサブネットのEC2にパブリックIPを割り当てます。

```hcl
resource "aws_instance" "web_private" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.private_a.id
  vpc_security_group_ids      = [aws_security_group.web.id]
  associate_public_ip_address = true  # パブリックIPを割り当てる

  user_data = <<-EOF
    #!/bin/bash
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "Hello from private subnet" > /var/www/html/index.html
  EOF

  tags = {
    Name = "network-basics-web-private"
  }
}
```

```bash
terraform apply
```

### AWS CLIで確認する

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=network-basics-web-private" "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].{InstanceId:InstanceId,PublicIp:PublicIpAddress,PrivateIp:PrivateIpAddress,SubnetId:SubnetId}" \
  --output table
```

```
--------------------------------------------------------------
|                     DescribeInstances                      |
+-------------+---------------+-----------------+------------+
| InstanceId  |   PrivateIp   |    PublicIp     |  SubnetId  |
+-------------+---------------+-----------------+------------+
| i-xxxxxxx   | 10.0.10.xxx   | 13.xxx.xxx.xxx  | subnet-xxx|
+-------------+---------------+-----------------+------------+
```

今度は `PublicIp` が割り当てられています。curlでアクセスしてみます。

```bash
curl --connect-timeout 5 http://13.xxx.xxx.xxx
# => curl: (28) Connection timed out
```

パブリックIPがあるにもかかわらず、タイムアウトします。

### なぜパブリックIPがあってもアクセスできないのか

原因はルートテーブルにあります。プライベートサブネットが使っているメインルートテーブルのルートを確認します。

| 送信先 | ターゲット |
|--------|----------|
| 10.0.0.0/16 | local |

`0.0.0.0/0 → IGW` のルートがありません。インターネットからのリクエストがEC2に到達したとしても、EC2からのレスポンスをインターネットに返す経路がないため、通信が成立しません。

つまり、インターネットとの通信には**パブリックIPとIGWへのルートの両方**が必要です。

| | パブリックIP | IGWへのルート | 通信 |
|---|---|---|---|
| パブリックサブネットのEC2 | あり | あり | できる |
| プライベートサブネットのEC2（デフォルト） | なし | なし | できない |
| プライベートサブネットのEC2（IP付与） | あり | なし | **できない** |

プライベートサブネットからインターネットに出たい場合は、NATゲートウェイを使いますが、今回は扱いません。

### 確認が終わったらプライベートサブネットのリソースを削除する

プライベートサブネットのリソースは確認用なので、削除しておきます。Terraformコードから `aws_subnet.private_a` と `aws_instance.web_private` を削除して `terraform apply` を実行するか、このまま次のステップでまとめて `terraform destroy` します。

## 7. リソースを削除する

検証が終わったらリソースを削除します。

```bash
terraform destroy
```

## まとめ

この記事では、以下のリソースをTerraformで作成しました。

| リソース | 役割 |
|---------|------|
| VPC | 自分専用の仮想ネットワーク |
| インターネットゲートウェイ | VPCとインターネットの出入り口 |
| サブネット | VPCのIPアドレス範囲を分割した区画。リソースはここに配置する |
| ルートテーブル | パケットの宛先を制御する。IGWへのルートを追加してパブリックサブネットにした |
| セキュリティグループ | リソースに対するファイアウォール |
| EC2 | Webサーバーを動かす仮想マシン |

次の記事では、このネットワーク構成の前にALBを配置して、複数のEC2にリクエストを負荷分散する構成を作ります。

## 参考

- [AWS Hands-on for Beginners Network編#1](https://pages.awscloud.com/JAPAN-event-OE-Hands-on-for-Beginners-Network1-2022-confirmation_945.html)
- [Amazon VPC ドキュメント](https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/what-is-amazon-vpc.html)
- [VPC CIDR ブロック](https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/vpc-cidr-blocks.html)
