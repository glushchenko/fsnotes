## 9. Containers

What is containers? This is place where your files are stored. Off course you can store notes without containers at all.

Open Preferences -> General -> Containers and select "None". Notes will be stored in plain text, Markdown or RTF.

But personally i am recommend to all use Text Bundle and Encrypted Text Bundles for sensitive data.

### Text Bundle

TextBundle – file format aims to provide a more seamless user experience when exchanging plain text files, like Markdown or RTF, between applications. http://textbundle.org

File extension – .textbundle

An example: Markdown files may contain references to external images. When sending such a file from a Markdown editor to a previewer, users will have to explicitly permit access to every single image file.
This is where TextBundle comes in. TextBundle brings convenience back - by bundling the Markdown text and all referenced images into a single file.

### Encrypted Text Bundle

Encrypted Text Bundle used for notes encryption? What is it?

Encrypted Text Bundle is Text Pack (zipped Text Bundle), but encrypted with RNCryptor.

File extension – .etp

The RNCryptor data format is cross-platform and there are many implementations. Under the hood we have:

AES-256 encryption
CBC mode
Password stretching with PBKDF2
Password salting
Random IV
Encrypt-then-hash HMAC
Open and cross platform

You can decrypt any FSNotes note with Python or Ruby, JS, etc. (full list you can found here)
Unzip and have fun with usual Text Bundle.