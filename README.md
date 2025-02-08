# Nomad Wiki
A space-efficient, text only copy of Wikipieda hosted with [NomadNet](https://github.com/markqvist/NomadNet).

> [!WARNING]  
> This project is a work in progress - error handling is rough and not all wikimedia formatting has been ported to micron.

## Limitations
* Can only search by article title
* Category pages do not work
* Not all wikimedia formatting has been translated to micron yet

## Quickstart

### Required Programs/Packages
* [NomadNet](https://github.com/markqvist/NomadNet)
* [PanDoc](https://pandoc.org/) - conversion from wikimedia format into micron syntax
* [RipGrep](https://github.com/BurntSushi/ripgrep) - searching index file

### Basic Setup
1. Clone the repository
2. Install the required utilities with `sudo apt install pandoc ripgrep`
3. Set up a symlink for wiki.py with `ln -s "$(pwd)/wiki.py" ~/.nomadnetwork/storage/pages/wiki.mu`
4. Run `download.sh` to grab the latest wikipedia exports
5. Link mu.lua into the `~/nomadwiki` folder with `ln -s "$(pwd)/mu.lua" ~/nomadwiki`

## Development

### Running Tests
Run conversion tests with `./test.sh`

# TODO
* organize/refactor python code
* sort / format search results
* move downloads to a dump folder, use data folder to store templates and python modules, and then symlink that to a static directory?
* add about page (or more info on the home screen?)
* wikimedia -> micron conversions/bugs
  * tables
  * annotations
  * nested bullet lists
* finish wiki race implementation
