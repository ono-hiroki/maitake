# =============================================================================
# パブリックIP
# =============================================================================
resource "azurerm_public_ip" "web" {
  name                = "${var.prefix}-web-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.tags
}

# =============================================================================
# ネットワークインターフェース（NIC）
# =============================================================================
resource "azurerm_network_interface" "web" {
  name                = "${var.prefix}-web-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.public.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.web.id
  }

  tags = var.tags
}

# =============================================================================
# Virtual Machine（EC2相当）
# =============================================================================
resource "azurerm_linux_virtual_machine" "web" {
  name                = "${var.prefix}-web-vm"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  size                  = "Standard_D2s_v3"
  admin_username        = "azureuser"
  network_interface_ids = [azurerm_network_interface.web.id]

  # SSH公開鍵認証
  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub")  # ローカルのSSH公開鍵を使用
  }

  # OS設定
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  # Ubuntu 22.04 LTS
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  # cloud-initでnginxをインストール
  custom_data = base64encode(<<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y nginx
    systemctl enable nginx
    systemctl start nginx
    echo "<h1>Hello from Azure VM!</h1><p>Hostname: $(hostname)</p>" > /var/www/html/index.html
  EOF
  )

  tags = var.tags
}
