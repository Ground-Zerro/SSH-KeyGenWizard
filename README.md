## SSH-KeyGenWizard


**Description**

SSH-KeyGenWizard is a script designed to automate the process of generating and managing SSH keys on a remote server.
- This script is designed primarily for Windows operating system users who do not have in-depth Linux knowledge.


**It performs the following functions**
- Loads the required software.
- Generates OpenSSH keys using the EdDSA algorithm.
- Converts the OpenSSH private key into PuTTY (.ppk) format.
- Copies the public key to a remote server (optional).
- Sets the correct permissions and SSH access settings on the server (optional).
- Creates a shortcut on the Windows desktop for quick access to the server using PuTTY (optional).


**Usefulness to the user**
- It provides a simple process to create a private SSH key and integrate it with a remote server.
- SSH key generation is done in a simple and straightforward question-answer form.
- The user is provided with information about successful completion of operations, as well as explanations in case of errors.


**At the end of the script provides the user with**
- A private-public key pair in OpenSSH and PuTTY formats, saved in a separate folder.
- A shortcut on the desktop for quick access to the server with one click (with authorization by private key).

**To summarize**
This script provides a convenient way to quickly and easily create SSH keys, copy them to a remote server and configure the connection, minimizing the need to manually perform multiple steps and use different software.
It is easy to use and provides feedback to the user in case of errors.
