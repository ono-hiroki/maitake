# =============================================================================
# VNet（仮想ネットワーク）
# =============================================================================
resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-vnet"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.0.0.0/16"]

  tags = var.tags
}

# =============================================================================
# サブネット
# =============================================================================

# パブリックサブネット（Bastionやロードバランサー用）
resource "azurerm_subnet" "public" {
  name                 = "${var.prefix}-public-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

# プライベートサブネット（アプリケーション用）
resource "azurerm_subnet" "private" {
  name                 = "${var.prefix}-private-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

# =============================================================================
# NSG（Network Security Group）
# =============================================================================

# パブリックサブネット用NSG
resource "azurerm_network_security_group" "public" {
  name                = "${var.prefix}-public-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # SSH許可（必要に応じてソースIPを制限）
  security_rule {
    name                       = "AllowSSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"  # 本番では制限すること
    destination_address_prefix = "*"
  }

  # HTTP許可
  security_rule {
    name                       = "AllowHTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # HTTPS許可
  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = var.tags
}

# プライベートサブネット用NSG
resource "azurerm_network_security_group" "private" {
  name                = "${var.prefix}-private-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # VNet内からのみ許可
  security_rule {
    name                       = "AllowVNetInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  # インターネットからの直接アクセスを拒否
  security_rule {
    name                       = "DenyInternetInbound"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  tags = var.tags
}

# =============================================================================
# NSGとサブネットの関連付け
# =============================================================================

resource "azurerm_subnet_network_security_group_association" "public" {
  subnet_id                 = azurerm_subnet.public.id
  network_security_group_id = azurerm_network_security_group.public.id
}

resource "azurerm_subnet_network_security_group_association" "private" {
  subnet_id                 = azurerm_subnet.private.id
  network_security_group_id = azurerm_network_security_group.private.id
}
