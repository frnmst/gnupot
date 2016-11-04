## Ideas to improve GNUpot (randomly sorted)

- Configuration can be saved in a json file which can the be parsed by `jq`, 
  `jshon` or similar. This avoids using the custom insufficient parser, and 
  makes possible having multiple servers and watch directories (since config 
  should be much easier to handle). This could be a big leap forward for the 
  quality of this script.

- Add a way to laung only 1 inotify process on the server so that all clients
  attach to this process in some way. This improved memory usage n the server.
  Is this feasable?

- Find someone for the artwork (main logo and other icons).

- Fix command line options and all ouputs to conform to the GNU coding 
  standards.
  - Use `getopt` in place of `getopts`.
  - Use outputs like in SINC.
  - Correct `form.sh` quotations.
  - Correct `printf "string\n"` to `print "%s\n" "string"`.

- Move all documentation to texinfo.

- (Move the repo to Savannah and keep GitHub as a mirror)?

- Get the best concepts from SINC.

- 1 source file + 1 default config file.

- Use `ssh -l username server` instead of `ssh username@server`. This is much 
  more readable. Do this whenever possible.
