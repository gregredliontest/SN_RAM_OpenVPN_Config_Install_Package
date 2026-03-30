# SN_RAM_OpenVPN_Config_Install_Package
📦 OpenVPN Client Config Installation Instructions
1. Prepare the ZIP Package
Open OpenVPN_client_config_install_example.zip
On Windows, use 7-Zip (recommended) or open directly in Explorer
Place your OpenVPN client configuration file in the root of the ZIP
Supported file types:
.ovpn
.conf
You should be able to drag and drop the file directly into the ZIP

⚠️ Important:

Only one .ovpn or .conf file must exist in the ZIP root
2. Replace Existing Config (If Needed)

If a config file already exists in the ZIP:

Delete the existing .ovpn or .conf file
Then add your new one

💡 Tip:

On Linux, you can update the ZIP using the zip command
On Windows, use 7-Zip to avoid modifying script formatting or permissions
3. Upload to the Device
Log in to your Red Lion SN/RAM device web interface
Navigate to:
Admin → Package Installation
<img width="663" height="317" alt="image" src="https://github.com/user-attachments/assets/30dd67c8-7092-4516-8125-d428319fb5e1" />

Select your updated ZIP file
<img width="1014" height="755" alt="image" src="https://github.com/user-attachments/assets/69d1dd60-be0e-4665-834e-7bdc0bdb7acf" />

Click Install
<img width="863" height="619" alt="image" src="https://github.com/user-attachments/assets/bfbc5867-5780-4b6f-9d62-aae2e9db7e16" />

4. What Happens During Installation

The device will automatically:

Extract and validate the OpenVPN configuration
Replace any existing OpenVPN config (if different)
Restart the OpenVPN service
✅ Installation Complete

Once the process finishes, your new OpenVPN configuration will be active.

🔧 Troubleshooting
Ensure only one .ovpn or .conf file is present in the ZIP root
Verify the file:
Uses valid OpenVPN syntax
Is compatible with OpenVPN 2.3 (SN/RAM requirement)

If installation fails:

Recreate the ZIP file using 7-Zip
Double-check the configuration file for syntax errors
