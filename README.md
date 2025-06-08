<div align="center" width="100%">
    <p><img width="60%" src="art/logo.png" alt="logo"></p>
</div>

# Parameters Control and Reporting Daemon
A Perl module to control local desktop environment. It is supposed to be used
together with WMs that do not provide DE-like features like brightness control
(like dwm).

PCRD was written with the following principles in mind:

- [x] should be light - low resource usage (0.3% of a single core in a riced setup)
- [x] should be stable - no unexpected exits and no memory leaks
- [x] should not be invasive - no weird defaults or magic behavior
- [x] should be configurable - config values are documented and there are few hardcodes
- [x] should be extensible - can be extended using plugins
- [x] should be capable - can be used as the central place for PC management

This module is mostly for self-use. Let me know if you are interested in using
it yourself.

## Code and documentation
Code on GitHub. Documentation as a man page - see `man PCRD`, `man pcrd` and
`man pcrctl`.

## Bugs and feature requests
Please use the Github's issue tracker to file both bugs and feature requests.

## Contributions
Contributions to the project in form of Github's pull requests are
welcome. Please make sure your code is in line with the general
coding style of the module. Let me know if you plan something
bigger so we can talk it through.

### Author
Bartosz Jarzyna <bbrtj.pro@gmail.com>

