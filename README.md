[![NIM](https://img.shields.io/badge/Nim-1.0.0-orange.svg?style=flat-square)](https://nim-lang.org)
[![LICENSE](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)](https://opensource.org/licenses/MIT)

# Svndaemon

This application is a Linux daemon to track log entries of the SVN repositories listed in an [Alasso](https://github.com/sthenic/alasso) database. The goal is to maintain a reflection of the revision metadata from the target repositories in the Alasso database.

## Docker
The included [Dockerfile](./Dockerfile) can be used to run svndaemon.

Build the docker image with
```
$ docker image build -t svndaemon .
```
and then run the container with
```
$ docker run --name svndaemon -it --rm --env ALASSO_URL=$ALASSO_URL -v $SVN_CRED_DIR:/root/.subversion svndaemon
```
where
* `ALASSO_URL`: The URL to the Alasso instance. E.g. `http://frontend-container/api` or `https://alasso.my-domain.com/api`
* `SVN_CRED_DIR`: Path to the .subversion directory with credentials for the SVN servers used in Alasso.

The SVN credentials can be generated with
```bash
$ svn ls --config $SVN_CRED_DIR $REPO_URL
```

## Version numbers
Releases follow [semantic versioning](https://semver.org/) to determine how the version number is incremented. If the specification is ever broken by a release, this will be documented in the changelog.

## License
This application is free software released under the [MIT license](https://opensource.org/licenses/MIT).

## Third-party dependencies

* [Nim's standard library](https://github.com/nim-lang/Nim)

## Author
This project is maintained by [Marcus Eriksson](mailto:marcus.jr.eriksson@gmail.com).
