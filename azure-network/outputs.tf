# =============================================================================
# VM関連のoutput
# =============================================================================
output "vm_public_ip" {
  description = "WebサーバーのパブリックIP"
  value       = azurerm_public_ip.web.ip_address
}

output "vm_ssh_command" {
  description = "SSH接続コマンド"
  value       = "ssh azureuser@${azurerm_public_ip.web.ip_address}"
}

output "vm_web_url" {
  description = "WebサーバーのURL"
  value       = "http://${azurerm_public_ip.web.ip_address}"
}
