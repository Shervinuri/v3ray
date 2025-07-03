import base64
import json
import requests
from urllib.parse import urlparse, urlunparse, quote, unquote
import os

# List of subscription links provided by the user
SUBSCRIPTION_URLS = [
    "https://raw.githubusercontent.com/mahsanet/MahsaFreeConfig/refs/heads/main/mci/sub_1.txt",
    "https://raw.githubusercontent.com/mahsanet/MahsaFreeConfig/refs/heads/main/mci/sub_2.txt",
    "https://raw.githubusercontent.com/mahsanet/MahsaFreeConfig/refs/heads/main/mci/sub_3.txt",
    "https://raw.githubusercontent.com/mahsanet/MahsaFreeConfig/refs/heads/main/mci/sub_4.txt",
    "https://raw.githubusercontent.com/mahsanet/MahsaFreeConfig/refs/heads/main/mtn/sub_1.txt",
    "https://raw.githubusercontent.com/mahsanet/MahsaFreeConfig/refs/heads/main/mtn/sub_2.txt",
    "https://raw.githubusercontent.com/mahsanet/MahsaFreeConfig/refs/heads/main/mtn/sub_3.txt",
    "https://raw.githubusercontent.com/mahsanet/MahsaFreeConfig/refs/heads/main/mtn/sub_4.txt",
    "https://v2.alicivil.workers.dev/?list=fi&count=500&shuffle=true&unique=false",
    "https://v2.alicivil.workers.dev/?list=us&count=500&shuffle=true&unique=false",
    "https://v2.alicivil.workers.dev/?list=gb&count=500&shuffle=true&unique=false",
    "https://raw.githubusercontent.com/soroushmirzaei/telegram-configs-collector/main/subscribe/protocols/vless",
    "https://raw.githubusercontent.com/soroushmirzaei/telegram-configs-collector/main/subscribe/protocols/vmess",
    "https://raw.githubusercontent.com/barry-far/V2ray-config/main/Splitted-By-Protocol/vless.txt",
    "https://raw.githubusercontent.com/barry-far/V2ray-config/main/Splitted-By-Protocol/vmess.txt",
    "https://raw.githubusercontent.com/youfoundamin/V2rayCollector/main/vmess_iran.txt",
    "https://raw.githubusercontent.com/youfoundamin/V2rayCollector/main/vless_iran.txt",
    "https://raw.githubusercontent.com/Epodonios/bulk-xray-v2ray-vless-vmess-...-configs/main/sub/United%20States/config.txt",
    "https://raw.githubusercontent.com/Epodonios/bulk-xray-v2ray-vless-vmess-...-configs/main/sub/Iran/config.txt",
    "https://raw.githubusercontent.com/Epodonios/bulk-xray-v2ray-vless-vmess-...-configs/main/sub/Germany/config.txt",
    "https://raw.githubusercontent.com/Epodonios/bulk-xray-v2ray-vless-vmess-...-configs/main/sub/Netherlands/config.txt",
    "https://raw.githubusercontent.com/darknessm427/V2ray-Sub-Collector/refs/heads/main/All_Darkness_Sub.txt"
]

NEW_CONFIG_NAME = "☬SHΞN™"
OUTPUT_FILE_NAME = "SHEN_SUB.txt" # The file that will be created/updated in the repo

def fetch_url_content(url):
    """Fetches content from a given URL."""
    try:
        response = requests.get(url, timeout=20) # Increased timeout
        response.raise_for_status() 
        return response.text
    except requests.exceptions.RequestException as e:
        print(f"Error fetching {url}: {e}")
        return None

def process_vmess(config_link, new_name):
    """Processes a VMESS link and changes its name (ps)."""
    if not config_link.startswith('vmess://'):
        return None
    try:
        base64_part = config_link[len('vmess://'):]
        missing_padding = len(base64_part) % 4
        if missing_padding:
            base64_part += '=' * (4 - missing_padding)
        
        decoded_json_str = base64.b64decode(base64_part).decode('utf-8')
        vmess_obj = json.loads(decoded_json_str)
        vmess_obj['ps'] = new_name
        new_json_str = json.dumps(vmess_obj, separators=(',', ':'))
        return 'vmess://' + base64.b64encode(new_json_str.encode('utf-8')).decode('utf-8')
    except Exception as e:
        print(f"Error processing VMESS link {config_link[:30]}...: {e}")
        return None

def process_vless(config_link, new_name):
    """Processes a VLESS link and changes its name (fragment part)."""
    if not config_link.startswith('vless://'):
        return None
    try:
        parsed_url = urlparse(config_link)
        new_fragment = quote(new_name)
        new_url_parts = list(parsed_url)
        new_url_parts[5] = new_fragment
        return urlunparse(new_url_parts)
    except Exception as e:
        print(f"Error processing VLESS link {config_link[:30]}...: {e}")
        return None

def process_shadowsocks(config_link, new_name):
    """Processes a Shadowsocks (ss) link and changes its name."""
    if not config_link.startswith('ss://'):
        return None
    try:
        parsed_url = urlparse(config_link)
        new_fragment = quote(new_name)
        new_url_parts = list(parsed_url)
        new_url_parts[5] = new_fragment
        return urlunparse(new_url_parts)
    except Exception as e:
        print(f"Error processing Shadowsocks link {config_link[:30]}...: {e}")
        return None

def get_all_processed_configs():
    """Fetches, processes, and combines all configurations."""
    processed_config_links = []

    for url_index, url in enumerate(SUBSCRIPTION_URLS):
        print(f"Processing URL {url_index + 1}/{len(SUBSCRIPTION_URLS)}: {url}...")
        content = fetch_url_content(url)
        if not content:
            print(f"Skipping {url} due to fetch error.")
            continue

        try:
            temp_decoded = base64.b64decode(content, validate=True).decode('utf-8')
            if "vmess://" in temp_decoded or "vless://" in temp_decoded or "ss://" in temp_decoded:
                current_configs_text = temp_decoded
                print(f"Successfully decoded Base64 content from {url}")
            else:
                current_configs_text = content
        except Exception:
            current_configs_text = content
        
        individual_links = current_configs_text.strip().splitlines()
        print(f"Found {len(individual_links)} potential links in {url}.")

        for i, link in enumerate(individual_links):
            link = link.strip()
            if not link:
                continue
            
            processed_link = None
            if link.startswith('vmess://'):
                processed_link = process_vmess(link, NEW_CONFIG_NAME)
            elif link.startswith('vless://'):
                processed_link = process_vless(link, NEW_CONFIG_NAME)
            elif link.startswith('ss://'):
                processed_link = process_shadowsocks(link, NEW_CONFIG_NAME)
            
            if processed_link:
                processed_config_links.append(processed_link)
            # else:
                # print(f"Link {i} from {url} was not processable or not a recognized type: {link[:50]}")


    if not processed_config_links:
        print("No processable configs found after checking all URLs.")
        return "" 

    print(f"Total processed configs: {len(processed_config_links)}")
    final_subscription_content = "\n".join(processed_config_links)
    return base64.b64encode(final_subscription_content.encode('utf-8')).decode('utf-8')

def main():
    print("Starting configuration aggregation...")
    aggregated_configs_base64 = get_all_processed_configs()
    
    if aggregated_configs_base64:
        # Ensure the output directory exists if specified in OUTPUT_FILE_NAME (e.g., "subs/SHEN_SUB.txt")
        output_dir = os.path.dirname(OUTPUT_FILE_NAME)
        if output_dir and not os.path.exists(output_dir):
            print(f"Creating output directory: {output_dir}")
            os.makedirs(output_dir)
            
        with open(OUTPUT_FILE_NAME, 'w', encoding='utf-8') as f:
            f.write(aggregated_configs_base64)
        print(f"Successfully wrote aggregated configs to {OUTPUT_FILE_NAME}")
        print(f"Total length of Base64 output: {len(aggregated_configs_base64)}")
    else:
        print(f"No configs to write. {OUTPUT_FILE_NAME} will not be created or modified if it exists and is empty.")
        # Optionally, create an empty file or ensure it's empty if no configs are found
        # For now, if it's empty, it just doesn't write.
        # If the GitHub Action expects the file to always exist, we might need to touch it:
        # with open(OUTPUT_FILE_NAME, 'w', encoding='utf-8') as f:
        #     f.write("") # Write empty string if no configs
        # print(f"{OUTPUT_FILE_NAME} is empty as no configs were found.")


if __name__ == '__main__':
    main()
