#!/usr/bin/env python3
"""Upload a video to YouTube, unlisted/private until Frank says go.

Usage: yt-upload.py VIDEO TITLE_FILE DESC_FILE [--public|--unlisted]
Default privacy is private. Credentials live outside any repo:
~/.config/youtube-upload/client_secrets.json (OAuth Desktop client
from Google Cloud Console, YouTube Data API v3 enabled) and the
cached token.json the first run writes next to it. First run opens a
browser for consent; later runs reuse the token.
"""
import argparse
import os
import sys

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from googleapiclient.http import MediaFileUpload

SCOPES = ["https://www.googleapis.com/auth/youtube.upload"]
CONFDIR = os.path.expanduser("~/.config/youtube-upload")
API = "youtube"
APIVER = "v3"


def authed():
    os.makedirs(CONFDIR, exist_ok=True)
    sec = os.path.join(CONFDIR, "client_secrets.json")
    tok = os.path.join(CONFDIR, "token.json")
    if not os.path.isfile(sec):
        sys.exit("missing %s: create an OAuth Desktop client in Google "
                 "Cloud Console (YouTube Data API v3) and save it there."
                 % sec)
    creds = None
    if os.path.isfile(tok):
        creds = Credentials.from_authorized_user_file(tok, SCOPES)
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            flow = InstalledAppFlow.from_client_secrets_file(sec, SCOPES)
            creds = flow.run_local_server(port=0)
        with open(tok, "w") as f:
            f.write(creds.to_json())
    return build(API, APIVER, credentials=creds)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("video")
    ap.add_argument("title_file")
    ap.add_argument("desc_file")
    ap.add_argument("--public", dest="privacy", action="store_const",
                    const="public")
    ap.add_argument("--unlisted", dest="privacy", action="store_const",
                    const="unlisted")
    ap.set_defaults(privacy="private")
    a = ap.parse_args()
    for p in (a.video, a.title_file, a.desc_file):
        if not os.path.isfile(p):
            sys.exit("no such file: %s" % p)
    with open(a.title_file) as f:
        title = f.read().strip()
    with open(a.desc_file) as f:
        desc = f.read().strip()
    if not title:
        sys.exit("title file is empty")
    yt = authed()
    req = yt.videos().insert(
        part="snippet,status",
        body={"snippet": {"title": title, "description": desc,
                          "categoryId": "10"},
              "status": {"privacyStatus": a.privacy,
                         "selfDeclaredMadeForKids": False}},
        media_body=MediaFileUpload(a.video, chunksize=8 * 1024 * 1024,
                                   resumable=True),
    )
    resp = None
    while resp is None:
        try:
            _st, resp = req.next_chunk()
        except HttpError as e:
            sys.exit("upload failed: %s" % e)
    vid = resp["id"]
    print("uploaded https://www.youtube.com/watch?v=%s (%s)"
          % (vid, a.privacy))


if __name__ == "__main__":
    main()
