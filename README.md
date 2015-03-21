# droogflow

A simple git-based workflow for Drupal 7 projects

This is nothing new.  It simply pulls together existing practices.

- Git controls everything except for user content and a tiny bit of config
- User content is mostly in the database, which is not kept in git
- All of drupal and its modules are kept in one flat git repo; no git submodules
- Workflow for keeping drupal core up to date is as documented in
  https://drupal.org/node/803746 (i.e. clone drupal core's git repo)
  except that we rebase our changes cleanly on top of the fresh drupal core
- Drupal modules are always added to git, one commit per module.
- Drupal module patches always applied one at a time, committing the
  module after each patch, with a link to the bug in the commit message
- Workflow for keeping drupal modules up to date is as documented in
  http://www.jenlampton.com/blog/keeping-your-drupal-site-date-git-and-drush
  (i.e. use drush dl to download modules, and check them into git)
  except that patches are documented in git commit log instead of a file
- Development is done on developer workstations, committed to developer git
  forks, code reviewed, pulled into the master git repo, then pulled
  onto a testing server for QA before being pulled onto the production
  server.

# Demo

The script demo.sh is a canned example for Ubuntu 14.04 that leads
you through the steps of cloning drupal, checking in modules,
creating a feature, pushing everything to the project repo.
and then pulling the project repo onto a second machine.

# Demo scenario
- Developer A follows https://drupal.org/node/803746 to clone latest release
  of drupal 7 and pushes it to a git repo on github
- Deveoper A uses "drush dl features" to download the features module,
  checks that into git, and pushes
- Developer B forks the repo on github, adds a new feature
  (e.g. a calendar per http://www.ostraining.com/blog/drupal/calendar-in-drupal,
  but with 'repeat' enabled in content type)
  creates a Feature encapsulating the config changes per
  http://www.ostraining.com/blog/drupal/features,
  commits each new module as a single command,
  then commits the Feature and any custom code to git as a single commit,
  pushes to her fork of the project, and
  does a pull request per https://help.github.com/articles/using-pull-requests
- Developer A receives the pull request and reviews it.  If it looks good,
  she accepts the change into the master repo.
- Developer A then logs in to the staging site, pulls the feature, and
  verifies that the site's old features still work, and that the new
  feature works.
- When all developers agree it's time to update the production site,
  a developer then logs in to the pruduction site, does a pull,
  verifies that the site's old features still work, and that the new
  feature works.

# Drupal core update scenario
- To start a project, begin by creating an empty project on github.
  Then clone it locally:
```
    $ git clone git@github.com:me/foo.git
    $ cd foo
```
  Add the current Drupal 7 (say, 7.27), tracking only the 7.x branch to save space, e.g.
```
    $ git remote add upstream -t 7.x http://git.drupal.org/project/drupal.git
    $ git fetch upstream
    $ git checkout 7.x
    $ git reset --hard 7.27
```
  Merge that into the master branch:
```
    $ git checkout master
    $ git merge 7.x
```
  Push everything to a git repo on github, e.g.
```
    $ git push origin --all
    $ git push origin --tags
```
- Development continues, with many commits and module updates on master branch as above
- New version of Drupal is released (say, 7.28)
- In a clean repo (with no outstanding changes waiting to be committed),
  Developer A grabs the new Drupal with git:
```
    $ git checkout 7.x
    $ git fetch
    $ git reset --hard 7.28
```
- Now the fun part: rebase master atop the new 7.x:
```
    $ git checkout master
    $ git rebase 7.x
```
- Review the git history to verify that your project's changes are
  now later in history than the updated Drupal core:
```
    $ git log
```
- And test locally.  Once it seems to be working, push everything:
```
    $ git push origin --all
    $ git push origin --tags
```
