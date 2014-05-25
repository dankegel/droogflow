#!/bin/sh
# Script to demonstrate simple git workflow for drupal 7 projects
# DO NOT RUN ON SYSTEMS WITH MYSQL INSTALLED.  IT WILL NUKE ALL MYSQL DATA.

set -e

# Update this to the latest version when convenient
drupalmajor=7
drupalminor=28

# Don't use this password if your MySQL server is on the public internet
sqlrootpw="q9z7a1"

# Let's keep our git client at $srctop/$projectname
# Always quote srctop and giturl, since $HOME might have spaces in it.
srctop="$HOME"/drupaldemo.tmp
projectname="caldemo"

# Where our master repository (source of truth) is
barerepo="$HOME"/bare/$projectname.git
# Edit this to be the hostname of the machine you're doing the first part of the demo on
barerepohostname=${MASTER:-caldemo-dev1}

# Ubuntu packages we need to install and uninstall in order to
# reproduce everything cleanly.
pkgs="mysql-client mysql-server drush php5-gd apache2 libapache2-mod-php5"

do_uninstall_deps() {
    echo "=== Warning, destroying all mysql data ==="
    set -x
    sudo apt-get remove $pkgs || true
    sudo apt-get purge $pkgs || true
    sudo apt-get autoremove || true
}

do_nuke() {
    echo "=== Warning, removing $srctop ==="
    set -x
    find "$srctop" -type d -print0 | xargs -0 chmod +w
    rm -rf "$srctop"
}

do_deps() {
    echo "When prompted, enter $sqlrootpw for the sql root password."
    sleep 4
    set -x
    sudo apt-get install -y $pkgs
}

do_mirror() {
    # Set up a mirror of drupal core
    # (Useful mostly for speeding up iterations of this script during testing)
    rm -rf ~/mirrors/drupal.git
    mkdir -p ~/mirrors/drupal.git
    git clone --bare http://git.drupal.org/project/drupal.git ~/mirrors/drupal.git
}

do_initgit() {
    set -x

    # Prepare our shared repo (eventually this would be on github)
    mkdir -p "$barerepo"
    cd "$barerepo"
    git init --bare

    # Prepare our master project repository
    mkdir -p "$srctop"/$projectname
    cd "$srctop"

    git clone "$barerepo" $projectname
    cd $projectname

    # Grab drupal
    git remote add drupal ~/mirrors/drupal.git
    git fetch drupal
    git checkout $drupalmajor.x
    git reset --hard $drupalmajor.$drupalminor
    git status

    # We're declaring our project to be the master branch (conveniently, drupal doesn't use that branch)
    git checkout -b master

    # Add a .gitignore file
    cat > .gitignore <<_EOF_
# Ignore configuration files that may contain sensitive information.
sites/*/settings*.php
# Ignore paths that contain user-generated content.
sites/*/files
sites/*/private
_EOF_
    git add .gitignore

    git commit -m "First commit for project $projectname"

    # Do initial push to our master repo
    git push origin master --tags
}

do_install() {
    if ! test -d "$srctop"/$projectname
    then
        echo "Please run '$0 initgit' or '$0 clone' first."
        exit 1
    fi
    set -x
    cd "$srctop"/$projectname
    # Note: older versions of drush didn't need the 'standard' word
    drush si standard --site-name=Example --db-url=mysql://root:$sqlrootpw@localhost/drupal --account-name=drupal --account-pass=drupal

    # FIXME: This is insecure, but required to pass the status report tests
    chmod 777 sites/default/files

    wwwdir=/var/www
    if test -d /var/www/html
    then
        wwwdir=/var/www/html
    fi
cat <<_EOF_
Now, if your web server is running, and this directory
is visible from it, and you have AllowOverrides turned on
for this directory, you ought to be able to log into the
drupal instance via a web browser with username drupal, password drupal.
You might need to do something like 'sudo ln -s $srctop/$projectname $wwwdir/$projectname
To turn on overrides, you might need to do 'sudo a2enmod rewrite'
and add a paragraph for $wwwdir/$projectname in /etc/apache2/sites-enabled/000-default*
per https://drupal.org/getting-started/clean-urls
You may also need to set base_url in sites/default/settings.php
_EOF_
    xdg-open http://localhost/$projectname 2> /dev/null || true
}

do_install_modules()
{
    for m
    do
        drush dl $m
        git add sites/all/modules/$m
        git commit -m "Add module $m"
    done
}

do_install_base_modules() {
    set -x
    cd "$srctop"/$projectname

    do_install_modules ctools devel features views
    drush en -y ctools
    drush en -y devel devel_generate
    drush en -y features
    drush en -y views views_ui
}

do_install_calendar7() {
    echo Home page: https://drupal.org/project/calendar
    echo See related tutorials:
    echo  https://drupal.org/node/1477602
    echo  http://www.ostraining.com/blog/drupal/calendar-in-drupal/
    echo  http://drupalize.me/series/calendars-drupal-7
    set -x
    cd "$srctop"/$projectname

    do_install_modules date calendar date_repeat_instance
    drush -y en ctools views_ui date date_popup calendar
    drush -y en date_repeat date_repeat_field date_repeat_instance

    # Work around bug https://drupal.org/node/1471400
    # FIXME: remove this once this bug is fixed
    wget https://drupal.org/files/calendar-php54-1471400-58.patch
    cat calendar-php54-1471400-58.patch | \
        (cd sites/all/modules/calendar; patch -p1)
    git add sites/all/modules/calendar
    git commit -m "calendar: apply patch for bug 1471400"

    xdg-open http://www.ostraining.com/blog/drupal/calendar-in-drupal/ 2> /dev/null || true
    cat << _EOF_
Now follow http://www.ostraining.com/blog/drupal/calendar-in-drupal/
to configure your calendar, and verify you can enter a few events.

Once it's working, follow http://www.ostraining.com/blog/drupal/features/
to save the calendar configuration as a Feature named mycalmod.

Then download the Feature, unpack it into sites/all/modules, do 'git add mycalmod',
and 'git commit -m "Added Feature mycalmod".'

Then do git push, and move on to trying to use the git repo from a second
machine (as described in usage message).
_EOF_
}

do_install_calendar() {
    case $drupalmajor in
    7) do_install_calendar7 ;;
    *) echo "what?"; exit 1;;
    esac
}

do_clone() {
    # You should be on the second machine now
    if ! ssh $barerepohostname true
    then
        echo "If $barerepohostname is not the hostname where you ran the first half of this demo,"
        echo "please edit this script to set the variable barehostname to that hostname."
        echo "Then make sure you can ssh there."
    fi
    mkdir -p "$srctop"
    cd "$srctop"
    git clone ${barerepohostname}:${barerepo} $projectname
    echo "Now run $0 install and see if the site comes up"'!'
}

usage() {
    cat <<_EOF_
Usage: $0 [deps|mirror|initgit|install|install_base_modules|install_calendar|nuke|uninstall_deps]
Script to demonstrate simple git workflow for drupal 7 projects
DO NOT RUN ON SYSTEMS WITH MYSQL INSTALLED.  IT WILL NUKE ALL MYSQL DATA.

First, read the script, and understand what it does.
Then, on a machine with no SQL data you care
about, run each of the verbs in order, e.g.
 $0 deps
 $0 mirror
 $0 initgit
 $0 install
 $0 install_base_modules
 $0 install_calendar (and follow instructions to create and check in a Feature)
 git push
 
Then on a second machine with no SQL data you care about:
 $0 deps
 $0 clone
 $0 install
and verify the calendar works on the second machine!
_EOF_
}

case $1 in
deps) do_deps;;
mirror) do_mirror;;
initgit) do_initgit;;
install) do_install;;
install_base_modules) do_install_base_modules;;
install_calendar) do_install_calendar;;
clone) do_clone;;
nuke) do_nuke;;
uninstall_deps) do_uninstall_deps;;
*) usage; exit 1;;
esac
