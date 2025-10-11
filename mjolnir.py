import os
import re
import time
import socket
import json
import instaloader
import requests
from bs4 import BeautifulSoup
from getpass import getpass
from colorama import Fore, init
import itertools
import threading
import webbrowser
import shutil

init(autoreset=True)
CREDENTIALS_FILE = "credential.txt"

def banner():
    width = shutil.get_terminal_size((80, 20)).columns

    ascii_art = rf"""{Fore.CYAN}  
   .___  ___.        __   _   _ __      .__   __.  __  .______      
   |   \/   |       |  | (_) (_)  |     |  \ |  | |  | |   _  \     
   |  \  /  |       |  |   ___ |  |     |   \|  | |  | |  |_)  |    
   |  |\/|  | .--.  |  |  / _ \|  |     |  . `  | |  | |      /     
   |  |  |  | |  `--'  | | (_) |  `----.|  |\   | |  | |  |\  \----.
   |__|  |__|  \______/   \___/|_______||__| \__| |__| | _| `._____|
                                                                    
{Fore.RESET}
"""
    print(ascii_art)

    print(Fore.CYAN + "[💀]Mjölnir - Fetch & download insta public profile")
    print(Fore.RED + "[⚠] For educational & security purposes only !!\n\n\n")
    print(Fore.CYAN + "Version = 1.0.0")
    print(Fore.CYAN + "Made by = Cyber Nobi")
    print(Fore.CYAN + "GitHub  = https://github.com/CyberNobii")
    print(Fore.CYAN + "Discord = https://discord/5RbRHk5B2c")
    print(Fore.CYAN + "Insta   = https://instagram.com/code_dreamerr_\n")  

def loading_animation(message, duration=25):
    done = False
    def animate():
        for c in itertools.cycle(['|', '/', '-', '\\']):
            if done:
                break
            print(f"\r{Fore.YELLOW}{message} {c}", end="", flush=True)
            time.sleep(0.5)
    t = threading.Thread(target=animate)
    t.start()
    time.sleep(duration)
    done = True
    print("\r" + " " * (len(message) + 4) + "\r", end="")

def check_internet(host="instagram.com", port=443, retries=4, delay=15):
    for attempt in range(1, retries + 1):
        try:
            socket.create_connection((host, port), timeout=5)
            return True
        except OSError:
            print(f"{Fore.RED}[!] Unable to reach {host} (attempt {attempt}/{retries})")
            time.sleep(delay)
    return False

def analyze_bio(bio):
    results = {"emails": [], "phones": [], "links": [], "mentions": []}
    if not bio:
        return results

    results["emails"] = re.findall(r"[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+", bio)
    results["phones"] = re.findall(r"\+?\d[\d -]{8,}\d", bio)
    results["links"] = re.findall(r"(https?://[^\s]+)", bio)
    results["mentions"] = re.findall(r"@([A-Za-z0-9._]+)", bio)
    return results

def bs4_scrape(username):
    try:
        loading_animation("Connecting to server...")
        url = f"https://www.instagram.com/{username}/"
        headers = {"User-Agent": "Mozilla/5.0"}
        response = requests.get(url, headers=headers, timeout=15)

        if response.status_code != 200:
            return None

        soup = BeautifulSoup(response.text, "html.parser")
        scripts = soup.find_all("script", type="application/ld+json")
        if not scripts:
            return None

        data = None
        for script in scripts:
            try:
                json_data = script.string
                if json_data and '"@type":"Person"' in json_data:
                    data = json.loads(json_data)
                    break
            except:
                pass

        if not data:
            return None

        print(f"\n{Fore.GREEN}[✔] Data successfully fetched !\n")
        print(f"{Fore.MAGENTA}================= Profile Information =================")
        print(f"{Fore.YELLOW}Username        : {username}")
        print(f"Full Name       : {data.get('name', 'N/A')}")
        bio = data.get("description", "")
        print(f"Bio             : {bio or 'No bio'}")
        print(f"Profile Pic URL : {data.get('image', 'N/A')}")
        analysis = analyze_bio(bio)
        if any(analysis.values()):
            print(f"{Fore.CYAN}\n[+] Advanced Bio Analysis")
            if analysis["emails"]: print(f"{Fore.YELLOW}Emails in Bio   : {', '.join(analysis['emails'])}")
            if analysis["phones"]: print(f"{Fore.YELLOW}Phones in Bio   : {', '.join(analysis['phones'])}")
            if analysis["links"]: print(f"{Fore.YELLOW}Links in Bio    : {', '.join(analysis['links'])}")
            if analysis["mentions"]: print(f"{Fore.YELLOW}Mentions in Bio : {', '.join(analysis['mentions'])}")
        return True
    except:
        return None

def instaloader_scrape(username):
    try:
        L = instaloader.Instaloader()
        loading_animation("Connecting to server...")
        profile = instaloader.Profile.from_username(L.context, username)
        print(f"\n{Fore.GREEN}[✔] Data successfully fetched via Instaloader!\n\n")
        print(f"{Fore.MAGENTA}================= Profile Information =================")
        print(f"{Fore.YELLOW}Username        : {profile.username}")
        print(f"Full Name       : {profile.full_name}")
        print(f"User ID         : {profile.userid}")
        print(f"Bio             : {profile.biography or 'No bio'}")
        print(f"External URL    : {profile.external_url or 'No link'}")
        print(f"Followers       : {profile.followers}")
        print(f"Following       : {profile.followees}")
        print(f"Posts           : {profile.mediacount}")
        print(f"Private?        : {'Yes' if profile.is_private else 'No'}")
        print(f"Verified?       : {'Yes' if profile.is_verified else 'No'}")
        print(f"Business?       : {'Yes' if profile.is_business_account else 'No'}")
        print(f"Business Cat.   : {getattr(profile, 'business_category_name', 'N/A')}")
        print(f"Category        : {getattr(profile, 'category_name', 'N/A')}")
        print(f"IGTV Count      : {getattr(profile, 'igtvcount', 'N/A')}")
        print(f"FB Page Linked  : {getattr(profile, 'connected_fb_page', 'N/A')}")
        print(f"Public Email    : {getattr(profile, 'public_email', 'Not available')}")
        print(f"Phone Number    : {getattr(profile, 'business_phone_number', 'Not available')}")
        print(f"Profile Pic URL : {profile.profile_pic_url}")

        analysis = analyze_bio(profile.biography)
        if any(analysis.values()):
            print(f"{Fore.CYAN}\n[+] Advanced Bio Analysis")
            if analysis["emails"]: print(f"{Fore.YELLOW}Emails in Bio   : {', '.join(analysis['emails'])}")
            if analysis["phones"]: print(f"{Fore.YELLOW}Phones in Bio   : {', '.join(analysis['phones'])}")
            if analysis["links"]: print(f"{Fore.YELLOW}Links in Bio    : {', '.join(analysis['links'])}")
            if analysis["mentions"]: print(f"{Fore.YELLOW}Mentions in Bio : {', '.join(analysis['mentions'])}")
        webbrowser.open(profile.profile_pic_url)
        return profile
    except Exception as e:
        print(f"{Fore.RED}[⚠] Failed to fetch data: {e}")
        return None

def login_instaloader():
    username = input(f"{Fore.CYAN}Enter Instagram ID: ")
    password = getpass(f"{Fore.CYAN}Enter Instagram Password: ")
    L = instaloader.Instaloader()
    try:
        L.login(username, password)
        with open(CREDENTIALS_FILE, "w") as f:
            f.write(f"{username}:{password}")
        print(f"{Fore.GREEN}[✔] Login successful & credentials saved!")
        return L
    except Exception as e:
        print(f"{Fore.RED}[⚠] Login failed: {e}")
        return None

def get_logged_in_loader():
    if os.path.exists(CREDENTIALS_FILE):
        with open(CREDENTIALS_FILE, "r") as f:
            creds = f.read().strip().split(":")
            if len(creds) == 2:
                L = instaloader.Instaloader()
                try:
                    L.login(creds[0], creds[1])
                    return L
                except:
                    print(f"{Fore.RED}[!] Saved credentials are invalid.")
                    return login_instaloader()
    return login_instaloader()

def download_data(L, profile):
    print(f"{Fore.YELLOW}[+] Downloading followers & following...")
    followers = [f.username for f in profile.get_followers()]
    following = [f.username for f in profile.get_followees()]
    with open("followers.txt", "w") as f:
        f.write("\n".join(followers))
    with open("following.txt", "w") as f:
        f.write("\n".join(following))
    print(f"{Fore.GREEN}[✔] Followers saved to followers.txt")
    print(f"{Fore.GREEN}[✔] Following saved to following.txt")
    print(f"{Fore.YELLOW}[+] Downloading latest 10 posts...")
    posts = profile.get_posts()
    for idx, post in enumerate(posts, start=1):
        if idx > 10:
            break
        L.download_post(post, target=profile.username)
    print(f"{Fore.GREEN}[✔] Latest 10 posts downloaded!\n")

def main():
    banner()
    loading_animation(f"{Fore.YELLOW}Connecting...")
    if not check_internet():
        print(f"{Fore.RED}[✖] No internet connection.")
        print(f"{Fore.RED}[⚠] Please check your network and try again.")
        return

    print(f"{Fore.GREEN}[✔] Internet connection OK!")
    while True:
        print(f"\n{Fore.MAGENTA}=========== Mjölnir ===========")
        print(f"{Fore.CYAN}1) Search Profile")
        print(f"{Fore.CYAN}2) Login")
        print(f"{Fore.CYAN}3) Exit")
        choice = input(f"{Fore.YELLOW}Choose an option: ").strip()

        if choice == "1":
            username = input(f"{Fore.YELLOW}Enter Instagram username: ").strip()
            if not bs4_scrape(username):
                profile = instaloader_scrape(username)
                if not profile:
                    continue
                ask = input(f"{Fore.CYAN}[?] Download posts & dump followers/following? (y/n): ").strip().lower()
                if ask == "y":
                    L = get_logged_in_loader()
                    if L:
                        profile = instaloader.Profile.from_username(L.context, username)
                        download_data(L, profile)

        elif choice == "2":
            login_instaloader()
        elif choice == "3":
            print(f"{Fore.GREEN}Goodbye!")
            break
        else:
            print(f"{Fore.RED}[!] Invalid choice, try again.")

if __name__ == "__main__":
    main()
