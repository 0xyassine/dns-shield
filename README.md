# DnsShield - Automatic DNS Blocklist Updater for Dnsmasq

![DnsShield Logo](https://raw.githubusercontent.com/0xyassine/logo/main/dns-shield.png)

## Description

DnsShield is a powerful and user-friendly script designed to automate the updating process of blocklists for Dnsmasq. With DnsShield, you can effortlessly maintain an up-to-date and comprehensive blocklist, enhancing security and privacy by blocking access to malicious or unwanted domains.

## Overview of Features

### 1. Auto Update with Crontab

DnsShield seamlessly integrates with crontab, allowing you to schedule automatic updates at specific intervals. This ensures that your blocklists are consistently refreshed with the latest data, providing real-time protection against emerging threats.

### 2. Customizable Update Based on Pre-defined Variable

You have full control over the update process with DnsShield's pre-defined variables. Easily set the desired update frequency, so you can strike the right balance between freshness and resource usage.

### 3. Flexible Category Management

DnsShield lets you enable or disable categories with ease. Tailor the blocklist to your specific needs by selecting the categories you want to block or allowing access to those you need.

### 4. Source-Level Control

Within each category, you can fine-tune the blocklist by enabling or disabling specific sources. This level of granularity allows you to customize protection based on your preferences and requirements.

### 5. Reduced Write Operations

DnsShield optimizes write operations to minimize disk/SD card wear. By efficiently managing updates, the script helps increase the lifespan of your storage media, ensuring durability and reliability.

### 6. Restore Old Blocklist

To enhance availability and mitigate potential failures with the newly generated block list, the system will automatically revert to the old block list in the event of any issues. This ensures a higher level of reliability and continuous operation.

### 7. Telegram Alerts on Failures

Stay informed about the status of blocklist updates with Telegram alerts. DnsShield can send notifications to your configured Telegram channel or group in case of update failures, allowing you to promptly address any issues.

## Getting Started

For more detailed instructions and tips, please refer to the [documentation](https://blog.byteninja.net/dns-shield-blocklists-updater/) on my personal blog.
