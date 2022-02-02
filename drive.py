from pydrive2.auth import GoogleAuth
from pydrive2.drive import GoogleDrive

gauth = GoogleAuth()

drive = GoogleDrive(gauth)

def upload(ID, fnames):
    for x in fnames:
        gfile = drive.CreateFile({'parents':[{'id':ID}]})
        gfile.SetContentFile(x)
        gfile.Upload()
        print(f"Upload Successful! Uploaded {x}")
    
def download(ID, titles):
    print(ID)
    file_list = drive.ListFile({'q': "'{}' in parents and trashed=false".format(ID)}).GetList()
    for x in file_list:
        for title in titles:
            if x['title'] == title:
                x.GetContentFile(x['title'])
                a = x.GetContentString('public_key.txt')
        print(f"Download Successful! Downloaded {x['title']}")

def trash(ID):
    file_list = drive.ListFile({'q': "'{}' in parents and trashed=false".format(ID)}).GetList()
    for x in file_list:
        x.Trash()

def replace(ID, title):
    print(title)
    print(ID)
    file_list = drive.ListFile({'q': "'{}' in parents and trashed=false".format(ID)}).GetList()
    for x in file_list:
        print("In loop")
        if x['title'] == title:
            print("Found the title")
            x.Trash()
    print("Out of loop")
    gfile = drive.CreateFile({'parents':[{'id':ID}]})
    gfile.SetContentFile(title)
    gfile.Upload()
    print(f"Upload Successful! Uploaded {x}")

def edit(PID, title, new_content):
    print(PID)
    file_list = drive.ListFile({'q': "'{}' in parents and trashed=false".format(PID)}).GetList()
    for x in file_list:
        if x['title'] == title:
            x.SetContentString(new_content)
            x.Upload()

def read(PID, title):
    file_list = drive.ListFile({'q': "'{}' in parents and trashed=false".format(PID)}).GetList()
    for x in file_list:
        if x['title'] == title:
            content = x.GetContentString(title)
            break
    print(f"Content = {content}")
    return content


def main(upload_id, download_id, fnames, mode):
    if mode == upload:
        upload(upload_id, fnames)
    elif mode == download:
        download(download_id)
