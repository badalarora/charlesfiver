# data "azurerm_subnet" "SubnetA" {
#   name                 = "SubnetA"
#   virtual_network_name = "app-network"
#   resource_group_name  = var.resource_group
# }

# data "azurerm_client_config" "current" {}
# resource "tls_private_key" "linux_key" {
#   algorithm = "RSA"
#   rsa_bits = 4096
# }

# # We want to save the private key to our machine
# # We can then use this key to connect to our Linux VM

# resource "local_file" "linuxkey" {
#   filename="linuxkey.pem"  
#   content=tls_private_key.linux_key.private_key_pem 
# }

resource "azurerm_resource_group" "app_grp" {
  name = var.resource_group[terraform.workspace]
  location = var.location

}

resource "azurerm_virtual_network" "app_network" {
  name                = "app-network"
  location            = var.location
  resource_group_name = azurerm_resource_group.app_grp.name
  address_space       = ["10.0.0.0/16"]
}
resource "azurerm_subnet" "SubnetA" {
  name                 = "SubnetA"
  resource_group_name  = var.resource_group
  virtual_network_name = azurerm_virtual_network.app_network.name
  address_prefixes     = ["10.0.1.0/24"]
  depends_on = [
    azurerm_virtual_network.app_network
  ]
}
// This interface is for appvm1
resource "azurerm_network_interface" "app_interface1" {
  name                = "app-interface1"
  location            = azurerm_resource_group.app_grp.location
  resource_group_name = azurerm_resource_group.app_grp.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.SubnetA.id
    private_ip_address_allocation = "Dynamic"
  }

  depends_on = [
    azurerm_virtual_network.app_network,
    azurerm_subnet.SubnetA
  ]
}
// This interface is for appvm2
resource "azurerm_network_interface" "app_interface2" {
  name                = "app-interface2"
  location            = azurerm_resource_group.app_grp.location
  resource_group_name = azurerm_resource_group.app_grp.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.SubnetA.id
    private_ip_address_allocation = "Dynamic"
  }

  depends_on = [
    azurerm_virtual_network.app_network,
    azurerm_subnet.SubnetA
  ]
}

// This is the resource for appvm1
resource "azurerm_windows_virtual_machine" "app_vm1" {
  name                = "appvm1"
  resource_group_name = azurerm_resource_group.app_grp.name
  location            = azurerm_resource_group.app_grp.location
  size                = "Standard_D2s_v3"
  admin_username      = "demousr"
  admin_password      = "Azure@123"
  availability_set_id = azurerm_availability_set.app_set.id
  network_interface_ids = [
    azurerm_network_interface.app_interface1.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  depends_on = [
    azurerm_network_interface.app_interface1,
    azurerm_availability_set.app_set
  ]
}

// This is the resource for appvm2
resource "azurerm_windows_virtual_machine" "app_vm2" {
  name                = "appvm2"
  resource_group_name = azurerm_resource_group.app_grp.name
  location            = azurerm_resource_group.app_grp.location
  size                = "Standard_D2s_v3"
  admin_username      = "demousr"
  admin_password      = "Azure@123"
  availability_set_id = azurerm_availability_set.app_set.id
  network_interface_ids = [
    azurerm_network_interface.app_interface2.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  depends_on = [
    azurerm_network_interface.app_interface2,
    azurerm_availability_set.app_set
  ]
}


resource "azurerm_availability_set" "app_set" {
  name                         = "app-set"
  location                     = azurerm_resource_group.app_grp.location
  resource_group_name          = azurerm_resource_group.app_grp.name
  platform_fault_domain_count  = 3
  platform_update_domain_count = 3
  depends_on = [
    azurerm_resource_group.app_grp
  ]
}

resource "azurerm_storage_account" "appstore" {
  name                     = "badal1997"
  resource_group_name      = azurerm_resource_group.app_grp.name
  location                 = azurerm_resource_group.app_grp.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

}

resource "azurerm_storage_container" "data" {
  name                  = "data"
  storage_account_name  = "appstore4577687"
  container_access_type = "blob"
  depends_on = [
    azurerm_storage_account.appstore
  ]
}

# Here we are uploading our IIS Configuration script as a blob
# to the Azure storage account

resource "azurerm_storage_blob" "IIS_config" {
  name                   = "IIS_Config.ps1"
  storage_account_name   = "appstore4577687"
  storage_container_name = "data"
  type                   = "Block"
  source                 = "IIS_Config.ps1"
  depends_on             = [azurerm_storage_container.data]
}

// This is the extension for appvm1
resource "azurerm_virtual_machine_extension" "vm_extension1" {
  name                 = "appvm-extension"
  virtual_machine_id   = azurerm_windows_virtual_machine.app_vm1.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"
  depends_on = [
    azurerm_storage_blob.IIS_config
  ]
  settings = <<SETTINGS
    {
        "fileUris": ["https://${azurerm_storage_account.appstore.name}.blob.core.windows.net/data/IIS_Config.ps1"],
          "commandToExecute": "powershell -ExecutionPolicy Unrestricted -file IIS_Config.ps1"     
    }
SETTINGS
}


// This is the extension for appvm2
resource "azurerm_virtual_machine_extension" "vm_extension2" {
  name                 = "appvm-extension"
  virtual_machine_id   = azurerm_windows_virtual_machine.app_vm2.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"
  depends_on = [
    azurerm_storage_blob.IIS_config
  ]
  settings = <<SETTINGS
    {
        "fileUris": ["https://${azurerm_storage_account.appstore.name}.blob.core.windows.net/data/IIS_Config.ps1"],
          "commandToExecute": "powershell -ExecutionPolicy Unrestricted -file IIS_Config.ps1"     
    }
SETTINGS
}


resource "azurerm_network_security_group" "app_nsg" {
  name                = "app-nsg"
  location            = azurerm_resource_group.app_grp.location
  resource_group_name = azurerm_resource_group.app_grp.name

  # We are creating a rule to allow traffic on port 80
  security_rule {
    name                       = "Allow_HTTP"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "nsg_association" {
  subnet_id                 = azurerm_subnet.SubnetA.id
  network_security_group_id = azurerm_network_security_group.app_nsg.id
  depends_on = [
    azurerm_network_security_group.app_nsg
  ]
}

// Lets create the Load balancer

resource "azurerm_public_ip" "load_ip" {
  name                = "load-ip"
  location            = azurerm_resource_group.app_grp.location
  resource_group_name = azurerm_resource_group.app_grp.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_lb" "app_balancer" {
  name                = "app-balancer"
  location            = azurerm_resource_group.app_grp.location
  resource_group_name = azurerm_resource_group.app_grp.name
  sku                 = "Standard"
  sku_tier            = "Regional"
  frontend_ip_configuration {
    name                 = "frontend-ip"
    public_ip_address_id = azurerm_public_ip.load_ip.id
  }

  depends_on = [
    azurerm_public_ip.load_ip
  ]
}

// Here we are defining the backend pool
resource "azurerm_lb_backend_address_pool" "PoolA" {
  loadbalancer_id = azurerm_lb.app_balancer.id
  name            = "PoolA"
  depends_on = [
    azurerm_lb.app_balancer
  ]
}

resource "azurerm_lb_backend_address_pool_address" "appvm1_address" {
  name                    = "appvm1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.PoolA.id
  virtual_network_id      = azurerm_virtual_network.app_network.id
  ip_address              = azurerm_network_interface.app_interface1.private_ip_address
  depends_on = [
    azurerm_lb_backend_address_pool.PoolA
  ]
}

resource "azurerm_lb_backend_address_pool_address" "appvm2_address" {
  name                    = "appvm2"
  backend_address_pool_id = azurerm_lb_backend_address_pool.PoolA.id
  virtual_network_id      = azurerm_virtual_network.app_network.id
  ip_address              = azurerm_network_interface.app_interface2.private_ip_address
  depends_on = [
    azurerm_lb_backend_address_pool.PoolA
  ]
}


// Here we are defining the Health Probe
resource "azurerm_lb_probe" "ProbeA" {
  # resource_group_name = azurerm_resource_group.app_grp.name
  loadbalancer_id = azurerm_lb.app_balancer.id
  name            = "probeA"
  port            = 80
  protocol        = "Tcp"
  depends_on = [
    azurerm_lb.app_balancer
  ]
}

// Here we are defining the Load Balancing Rule
resource "azurerm_lb_rule" "RuleA" {
  # resource_group_name            = azurerm_resource_group.app_grp.name
  loadbalancer_id                = azurerm_lb.app_balancer.id
  name                           = "RuleA"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "frontend-ip"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.PoolA.id]
  depends_on = [
    azurerm_lb.app_balancer
  ]
}

// This is used for creating the NAT Rules

resource "azurerm_lb_nat_rule" "NATRuleA" {
  resource_group_name            = azurerm_resource_group.app_grp.name
  loadbalancer_id                = azurerm_lb.app_balancer.id
  name                           = "RDPAccess"
  protocol                       = "Tcp"
  frontend_port                  = 3389
  backend_port                   = 3389
  frontend_ip_configuration_name = "frontend-ip"
  depends_on = [
    azurerm_lb.app_balancer
  ]
}


# resource "azurerm_linux_virtual_machine" "linux_vm" {
#   name                = "linuxvm"
#   resource_group_name = var.resource_group
#   location            = var.location
#   size                = "Standard_D2s_v3"
#   admin_username      = "linuxusr"  
#   network_interface_ids = [
#     azurerm_network_interface.app_interface.id,
#   ]
#   admin_ssh_key {
#     username   = "linuxusr"
#     public_key = tls_private_key.linux_key.public_key_openssh
#   }
#   os_disk {
#     caching              = "ReadWrite"
#     storage_account_type = "Standard_LRS"
#   }

#   source_image_reference {
#     publisher = "Canonical"
#     offer     = "UbuntuServer"
#     sku       = "18.04-LTS"
#     version   = "latest"
#   }


#   depends_on = [
#     azurerm_network_interface.app_interface
#   ]
# }

# resource "azurerm_public_ip" "app_public_ip" {
#   name                = "app-public-ip"
#   resource_group_name = var.resource_group
#   location            = var.location
#   allocation_method   = "Static"
# }

resource "azurerm_managed_disk" "data_disk" {
  name                 = "data-disk"
  location             = var.location
  resource_group_name  = var.resource_group
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 16
}
# Then we need to attach the data disk to the Azure virtual machine
# resource "azurerm_virtual_machine_data_disk_attachment" "disk_attach" {
#   managed_disk_id    = azurerm_managed_disk.data_disk.id
#   virtual_machine_id = azurerm_windows_virtual_machine.app_vm.id
#   lun                = "0"
#   caching            = "ReadWrite"
#   depends_on = [
#     azurerm_windows_virtual_machine.app_vm,
#     azurerm_managed_disk.data_disk
#   ]
# }

# resource "azurerm_availability_set" "app_set" {
#   name                = "app-set"
#   location            = var.location
#   resource_group_name = var.resource_group
#   platform_fault_domain_count = 3
#   platform_update_domain_count = 3  
#   depends_on = [
#     azurerm_resource_group.app_grp
#   ]
# }
resource "azurerm_app_service_plan" "app_plan1000" {
  name                = "app-plan1000"
  location            = azurerm_resource_group.app_grp.location
  resource_group_name = azurerm_resource_group.app_grp.name

  sku {
    tier = "Basic"
    size = "B1"
  }
}

resource "azurerm_app_service" "webapp" {
  name                = "badalwebapp1998"
  location            = azurerm_resource_group.app_grp.location
  resource_group_name = azurerm_resource_group.app_grp.name
  app_service_plan_id = azurerm_app_service_plan.app_plan1000.id
}
# resource "azurerm_storage_account" "appstore" {
#   name                     = "badal1998"
#   resource_group_name      = "app-grp"
#   location                 = "North Europe"
#   account_tier             = "Standard"
#   account_replication_type = "LRS"
# }

# resource "azurerm_storage_container" "data" {
#   name                  = "data"
#   storage_account_name  = var.storage_account_name
#   container_access_type = "blob"
#   depends_on=[
#     azurerm_storage_account.appstore
#     ]
# }

# Here we are uploading our IIS Configuration script as a blob
# to the Azure storage account

# resource "azurerm_storage_blob" "IIS_config" {
#   name                   = "IIS_Config.ps1"
#   storage_account_name   = "appstore4577687"
#   storage_container_name = "data"
#   type                   = "Block"
#   source                 = "IIS_Config.ps1"
#    depends_on=[azurerm_storage_container.data]
# }

# resource "azurerm_virtual_machine_extension" "vm_extension" {
#   name                 = "appvm-extension"
#   virtual_machine_id   = azurerm_windows_virtual_machine.app_vm.id
#   publisher            = "Microsoft.Compute"
#   type                 = "CustomScriptExtension"
#   type_handler_version = "1.10"
#   depends_on = [
#     azurerm_storage_blob.IIS_config
#   ]
#   settings = <<SETTINGS
#     {
#         "fileUris": ["https://${azurerm_storage_account.appstore.name}.blob.core.windows.net/data/IIS_Config.ps1"],
#           "commandToExecute": "powershell -ExecutionPolicy Unrestricted -file IIS_Config.ps1"     
#     }
# SETTINGS

# }

# resource "azurerm_network_security_group" "app_nsg" {
#   name                = "app-nsg"
#   location            = var.location
#   resource_group_name = var.resource_group
# # We are creating a rule to allow traffic on port 80
#   security_rule {
#     name                       = "Allow_HTTP"
#     priority                   = 200
#     direction                  = "Inbound"
#     access                     = "Allow"
#     protocol                   = "Tcp"
#     source_port_range          = "*"
#     destination_port_range     = "80"
#     source_address_prefix      = "*"
#     destination_address_prefix = "*"
#   }
# }

# resource "azurerm_subnet_network_security_group_association" "nsg_association" {
#   subnet_id                 = azurerm_subnet.SubnetA.id
#   network_security_group_id = azurerm_network_security_group.app_nsg.id
#   depends_on = [
#     azurerm_network_security_group.app_nsg
#   ]
# }
# Here we are creating a storage account.
# The storage account service has more properties and hence there are more arguements we can specify here

# resource "azurerm_storage_account" "badal" {
#  name                     = var.storage_account_name
#   resource_group_name      = var.resource_group 
#   location                 = var.location
#   account_tier             = "Standard"
#   account_replication_type = "GRS"
#   depends_on = [ azurerm_resource_group.app_grp ]

# }

# # Here we are creating a container in the storage account
# resource "azurerm_storage_container" "data" {
#   name                  = "data"
#   storage_account_name  = var.storage_account_name
#   container_access_type = "blob"
#   depends_on = [ azurerm_storage_account.badal ]
# }

# # This is used to upload a local file onto the container
# resource "azurerm_storage_blob" "sample" {
#   name                   = "main.tf"
#   storage_account_name   = var.storage_account_name
#   storage_container_name = azurerm_storage_container.data.name
#   type                   = "Block"
#   source                 = "main.tf"
#   depends_on=[azurerm_storage_container.data]
# }
#keyvault
# resource "azurerm_key_vault" "app_vault" {  
#   name                        = "appvault9087878"
#   location                    = var.location
#   resource_group_name         = var.resource_group  
#   tenant_id                   = data.azurerm_client_config.current.tenant_id
#   soft_delete_retention_days  = 7
#   purge_protection_enabled    = false
#   sku_name = "standard"
#   access_policy {
#     tenant_id = data.azurerm_client_config.current.tenant_id
#     object_id = data.azurerm_client_config.current.object_id
#     key_permissions = [
#       "get",
#     ]
#     secret_permissions = [
#       "get", "backup", "delete", "list", "purge", "recover", "restore", "set",
#     ]
#     storage_permissions = [
#       "get",
#     ]
#   }
#   depends_on = [
#     azurerm_resource_group.app_grp
#   ]
# }

# # We are creating a secret in the key vault
# resource "azurerm_key_vault_secret" "vmpassword" {
#   name         = "vmpassword"
#   value        = "Azure@123"
#   key_vault_id = azurerm_key_vault.app_vault.id
#   depends_on = [ azurerm_key_vault.app_vault ]
# }
