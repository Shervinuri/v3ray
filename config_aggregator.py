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
        # Ensure base64_part is ASCII, otherwise b64decode will fail with non-ASCII chars
        # However, the error "string argument should contain only ASCII characters" for b64decode
        # usually implies the *input string itself* (base64_part) has non-ASCII chars,
        # which it shouldn't if it's valid Base64.
        # Let's add a specific catch for errors during b64decode.

        missing_padding = len(base64_part) % 4
        if missing_padding:
            base64_part += '=' * (4 - missing_padding)
        
        decoded_json_str = base64.b64decode(base64_part).decode('utf-8') # This line can fail
        vmess_obj = json.loads(decoded_json_str)
        vmess_obj['ps'] = new_name
        new_json_str = json.dumps(vmess_obj, separators=(',', ':'))
        return 'vmess://' + base64.b64encode(new_json_str.encode('utf-8')).decode('utf-8')
    except (TypeError, ValueError) as e: # Catches "string argument should contain only ASCII characters" from b64decode, among others
        print(f"Base64 Decode Error or ValueError processing VMESS link {config_link[:80]}...: {e}")
        return None
    except json.JSONDecodeError as e:
        # This variable would not be defined if base64.b64decode failed, so we need to handle that.
        decoded_str_preview = "Error during Base64 decoding, so decoded_json_str is not available."
        try:
            # Attempt to show part of the base64_part if decoded_json_str isn't available.
            decoded_str_preview = f"Problematic Base64 part (first 100 chars): '{base64_part[:100]}'"
        except NameError: # base64_part might not be defined if error is very early.
            pass
        print(f"JSON Decode Error processing VMESS link {config_link[:30]}...: {e}. {decoded_str_preview}")
        return None
    except Exception as e:
        print(f"Generic Error processing VMESS link {config_link[:30]}...: {e}")
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
                # This case means Base64 decoding was successful, but the decoded content didn't look like typical config URLs.
                # It's possible the original content *was* plain text and just happened to be valid Base64.
                # Or, it's Base64 but not a list of configs. We'll assume it might be plain text if it doesn't fit the pattern.
                print(f"Content from {url} decoded from Base64, but no standard config prefixes found. Treating as potential plain text.")
                current_configs_text = content # Fallback to original content if decoded version isn't right
        except Exception as e_base64:
            # print(f"Could not decode Base64 from {url}: {e_base64}. Assuming plain text.")
            current_configs_text = content # Assume plain text if not valid Base64
        
        individual_links = current_configs_text.strip().splitlines()
        print(f"Found {len(individual_links)} potential config lines in {url}.")

        for i, link in enumerate(individual_links):
            link = link.strip()
            if not link:
                continue
            
            processed_link = None
            original_link_prefix = link[:10] # For logging

            if link.startswith('vmess://'):
                processed_link = process_vmess(link, f"{NEW_CONFIG_NAME}_{url_index+1}_{i+1}")
            elif link.startswith('vless://'):
                processed_link = process_vless(link, f"{NEW_CONFIG_NAME}_{url_index+1}_{i+1}")
            elif link.startswith('ss://'):
                processed_link = process_shadowsocks(link, f"{NEW_CONFIG_NAME}_{url_index+1}_{i+1}")
            else:
                print(f"Link {i+1} from {url} (starts with '{original_link_prefix}...') is not a recognized type, skipping.")
            
            if processed_link:
                processed_config_links.append(processed_link)
            # else:
                # print(f"Link {i+1} from {url} (starts with '{original_link_prefix}...') failed processing or was skipped.")


    if not processed_config_links:
        print("No processable configs found after checking all URLs.")
        return "" # Return empty string, main function will handle file creation

    print(f"Total processed configs successfully: {len(processed_config_links)}")
    final_subscription_content = "\n".join(processed_config_links)
    return base64.b64encode(final_subscription_content.encode('utf-8')).decode('utf-8')

def main():
    print("Starting configuration aggregation...")
    aggregated_configs_base64 = get_all_processed_configs()
    
    # Ensure the output directory exists if specified in OUTPUT_FILE_NAME
    output_dir = os.path.dirname(OUTPUT_FILE_NAME)
    if output_dir and not os.path.exists(output_dir):
        print(f"Creating output directory: {output_dir}")
        os.makedirs(output_dir)
            
    with open(OUTPUT_FILE_NAME, 'w', encoding='utf-8') as f:
        if aggregated_configs_base64:
            f.write(aggregated_configs_base64)
            print(f"Successfully wrote aggregated configs to {OUTPUT_FILE_NAME}")
            print(f"Total length of Base64 output: {len(aggregated_configs_base64)}")
        else:
            f.write("") # Write an empty string if no configs were found
            print(f"No processable configs found. {OUTPUT_FILE_NAME} has been emptied or created empty.")


if __name__ == '__main__':
    main()
