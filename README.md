# ARK Server Docker

This is a docker container for running an ARK Dedicated Server. This is based on
my (Project Zomboid Server Docker Container)[https://github.com/voidstar240/pzserver-docker].
This server also pauses when no players are connected! The included RCON client
is written by \[ASY\]Zyrain and was sourced from the
(Ryan Schulze's Archive)[http://www.asyserver.com/~cstrike/rcon.c], as the
original source, [http://www.asyserver.com/] is no longer in available.

Note: I have not tested this on Windows YMMV... but it probably won't work.

## IMPORTANT

**Change `ADMIN_PASSWORD` in `.env` before starting the container!**  

## Usage

1. Clone this repo.
2. `$ cd arkserver-docker`
3. `$ mkdir data`
4. `$ cp start.sh data/start.sh`
5. SET ADMIN PASSWORD IN `.env`!
6. `# docker compose up`

## Configuration

The ARK `Saved/` directory is separated from the `server_files/` directory and
is located in `data/saved/`.

## Contributing

This project is open to contribution. If you are a user experiencing a problem
that you can reproduce, please submit an issue. If you are a developer looking
to help, create a pull request.
