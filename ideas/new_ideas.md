# Ideas to improve GNUpot

## Top priority

### GNU coding standards

- Fix command line options and all ouputs to conform to the GNU coding 
  standards.
- Use `getopt` in place of `getopts`.
- Use outputs like in SINC.
- Correct `form.sh` quotations.
- Correct `printf "string\n"` to `print "%s\n" "string"`.
- Move all documentation to texinfo.

### Other

- Configuration can be saved in a json file which can then be parsed by `jq`, 
  `jshon` or similar. This avoids using the custom insufficient parser, and 
  makes possible having multiple servers and watch directories (since config 
  should be much easier to handle). This could be a big leap forward for the 
  quality of this script. Other possibilites besided JSON are: XML, YAML or 
  even TOML (unfortunately I haven't found any shell parser for TOML).
  **I guess I'll stick with JSON and [`jq`](https://stedolan.github.io/jq/)
  as the parser. This seems to be the best bet**. Packages are available for 
  Trisquel and Parabola (and I guess for most free distros).

- Use [GNU Parallel](https://www.gnu.org/software/parallel/) to handle
  multi-server and multi-directory situations (instead of for loops or
  similar)?

- Add a way to launch only 1 inotify process on the server so that all clients
  attach to this process in some way. This improved memory usage in the server.
  - Is this feasable?

- Use `ssh -l username server` instead of `ssh username@server`. This is much
  more readable. Do it whenever possible.
  


## Artwork

- Find someone for the artwork (main logo and other icons).

## Other

- (Move the repo to Savannah and keep GitHub as a mirror)?

- Get the best remaining concepts from SINC.
  - Is using fake closures a good idea?

- 1 source file + 1 default config file.


