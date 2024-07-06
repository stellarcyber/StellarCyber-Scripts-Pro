# StellarCyber-Scripts-Pro

StellarCyber-Scripts-Pro is a CLI-based menu interface with dynamic options loaded from a `config.json` file. It allows users to navigate through a menu structure, execute scripts, simulate actions, and display help information. It is the upgraded version of the basic [StellarCyber-Scripts](https://github.com/ash14545/StellarCyber-Scripts) project.

## Features

* **Dynamic Menu**: Options are read from `config.json` using `jq` and display dynamically in a horizontal menu format.

* **Navigation**: Users can navigate the menu using arrow keys (`up`, `down`, `left`, `right`) and select options using the `Enter` key.

* **Submenus**: Each main option can lead to a submenu with the following options: `Run`, `Help`, `Simulate`, `Back`.

* **Script Downloading**: Automatically downloads scripts from GitHub Gist URLs related to each option in `config.json` if they are missing locally.

* **ANSI Color Support**: Uses ANSI color codes for enhanced terminal display

## Requirements

Please ensure that you are running in a **Linux environment**. Windows users can use the [Git Bash](https://git-scm.com/) CLI.

* `jq`: Required for parsing `config.json` and other json files and responses.
* `curl`: Required for downloading scripts from URLs.

## Installation

1. Clone the repository

```bash
git clone https://github.com/ash14545/StellarCyber-Scripts-Pro.git
cd StellarCyber-Scripts-Pro
```

2. Ensure the script has the proper permissions to run

```bash
chmod +x master_script.sh
```

## Usage

Run the main script to start the interactive menu:

```
./master_script.sh
```

Follow the on-screen instructions to navigate through the menu options, download scripts, and perform tasks.

## Configuration

* **config.json**: Contains options and URLs for downloading scripts. Modify this file to add new scripts or update existing ones.

## Contributing

Contributions are welcome! If you have improvements or new features to add, feel free to fork the repository and submit a pull request.

Please make sure to update tests as appropriate.

## License

This project is licensed under the [MIT license](https://choosealicense.com/licenses/mit/).