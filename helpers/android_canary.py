#!/usr/bin/env python3
"""
helpers/android_canary.py — Resolves the latest Android Studio Canary Linux release.
Queries Google's Canary update channel XML (AI-1-eap) and preview page metadata.
Outputs 3 lines on success:
  Line 1: Version display name (e.g., "Android Studio Ladybug Feature Drop | 2024.2.2 Canary 1")
  Line 2: Build number (e.g., "242.23726.103")
  Line 3: Direct CDN download URL
Exits 0 on success, 1 on failure.
"""

import sys
import re
import urllib.request
import xml.etree.ElementTree as ET


def check_url(url: str, timeout: int = 4) -> bool:
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "Mozilla/5.0", "Range": "bytes=0-10"}
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.status in (200, 206)
    except Exception:
        return False


def get_canary_metadata():
    found_url = None
    found_ver = None
    found_build = None

    # 1. Inspect developer.android.com preview page HTML
    try:
        p_req = urllib.request.Request(
            "https://developer.android.com/studio/preview",
            headers={"User-Agent": "Mozilla/5.0"}
        )
        with urllib.request.urlopen(p_req, timeout=5) as p_resp:
            p_html = p_resp.read().decode("utf-8", errors="ignore")

        m_url = re.search(
            r"data-category=[\"']canary_linux_bundle_download[\"'][^>]*href=[\"'](https://[^\s\"']+)[\"']",
            p_html
        )
        if not m_url:
            m_url = re.search(
                r"href=[\"'](https://[^\s\"']+android-studio[^\s\"']*-linux\.tar\.gz)[\"'][^>]*data-category=[\"']canary_linux_bundle_download[\"']",
                p_html
            )
        if m_url and check_url(m_url.group(1)):
            found_url = m_url.group(1)
            m_title = re.search(
                r"data-text=[\"']Download (Android Studio [^\s\"'][^\"']*)[\"']",
                p_html
            )
            if m_title:
                found_ver = m_title.group(1)
    except Exception:
        pass

    # 2. Inspect dl.google.com updates.xml channel AI-1-eap
    try:
        u_req = urllib.request.Request(
            "https://dl.google.com/android/studio/patches/updates.xml",
            headers={"User-Agent": "Mozilla/5.0"}
        )
        with urllib.request.urlopen(u_req, timeout=5) as u_resp:
            u_xml = u_resp.read()
        root = ET.fromstring(u_xml)
        ch = next((c for c in root.findall(".//channel") if c.get("id") == "AI-1-eap"), None)
        if ch is not None:
            if found_url:
                for b in ch.findall("build"):
                    if found_ver and (b.get("version", "") in found_ver or found_ver in b.get("version", "")):
                        found_build = b.get("number")
                        break
                if not found_build:
                    first = ch.find("build")
                    if first is not None:
                        found_build = first.get("number")
            else:
                for b in ch.findall("build")[:6]:
                    ver = b.get("version", "")
                    num = b.get("number", "")
                    m = re.match(r"([A-Za-z]+)\s*(\d+)?\s*\|\s*([\d\.]+)\s+Canary\s+(\d+)", ver)
                    if m:
                        codename = m.group(1).lower()
                        major = m.group(2) or ""
                        rel = m.group(3)
                        canary = m.group(4)
                        dir_v = f"{rel}.{canary}"
                        fname = f"android-studio-{codename}{major}-canary{canary}-linux.tar.gz"
                        cand_url = f"https://edgedl.me.gvt1.com/android/studio/ide-zips/{dir_v}/{fname}"
                        if check_url(cand_url):
                            found_url = cand_url
                            found_ver = f"Android Studio {ver}"
                            found_build = num
                            break
    except Exception:
        pass

    if found_url and found_ver:
        print(found_ver)
        print(found_build if found_build else "none")
        print(found_url)
        return 0
    return 1


if __name__ == "__main__":
    sys.exit(get_canary_metadata())
