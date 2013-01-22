# Jenkins Gitlab Hook Plugin

Enables Gitlab web hooks to be used to trigger SMC polling on Gitlab projects

Plugin details can be found at https://wiki.jenkins-ci.org/display/JENKINS/Gitlab+Hook+Plugin

## Why?

For [Gitlab](http://gitlabhq.com) there is an existing solution that might work for you.
You can just use the notifyCommit hook on [Git plugin](https://wiki.jenkins-ci.org/display/JENKINS/Git+Plugin) like this:

```
http://your-jenkins-server/git/notifyCommit?url=<URL of the Git repository for the Gitlab project>
```

But, with a large number of projects that are mostly polling (no hooks), the project might actually be built with a great delay (5 to 20 minutes).
You can find more details about notifyCommit and this issue [here](http://kohsuke.org/2011/12/01/polling-must-die-triggering-jenkins-builds-from-a-git-hook).

That is where this plugin comes in.
It gives you the option to use build\_now or notify\_commit hook, whichever suits your needs better.

### Build now hook

Add this web hook on your Gitlab project: 

```
http://your-jenkins-server/gitlab/build_now
```

Plugin will parse the Gitlab payload and extract the branch for which the commit is being pushed and changes made.
It will then scan all Git projects in Jenkins and start the build for those that:

* match url of the Gitlab repo
* and match committed Gitlab branch

Notes:

* for branch comparison, it will take into account both the branch definition and the strategy (this is different from the original notifyCommit)
* the project must be enabled
* you don't have to setup polling for the project

#### Parametrized projects

Plugin will recognize projects that are parametrized and will use the default parameter values for the build.
In case you define a parameter inside the branch specifier, plugin will replace the parameter value with the commit branch from the payload.
Replacing is done by matching **${PARAMETER\_KEY}** in branch specifier to the parameter list for the project.

This is usefull e.g. when you want to define a single project for all the branches in the repository.
Setup might look like this:

* parametrized build with string parametere **BRANCH\_TO\_BUILD**, default = master
* branch specifier: **origin/${BRANCH\_NAME\_TO\_BUILD}**

With this configuration:

* you can start a manual build of a project, it will ask for a branch to build
* gitlab build now hook will set the branch to be built using the specified parameter

Advantages of this approach:

* one Jenkins project per Git(lab) repository
* builds all branches
* no concurrent builds occur for the same Git(lab) repository

Disadvantages:

* Jenkins can't resolve dependencies between Maven projects automatically because Jenkins projects reference different branches at different times
* job / branch monitoring is not easy because all builds are contained within the same Jenkins project

#### Automatic branch project creation

# TODO: add screenshots of settings

In case you might want to approach multiple branches by having a separate Jenkins project for each Git(lab) repository, you can turn on the appropriate plugin option.
This use case workflow:

* if exists a Jenkins project that exactly maches the commited branch
  * build the matching project
* else
  * copy the master project
  * name the project according to the repository and commited branch name
  * adjust SCM settings to reflect the commited branch and repository
  * build the new project

Notes:

* it can be one of the following (determined in given order):
  * project that references the given repo url and master branch
    master branch can be set in Jenkins main configuration, "master" is the default
  * project that references the given repo url for any other branch
* the master project for the given repo is required because
  this is currently the only way to copy git settings
  (e.g. you could use ssh or http access)
* everything you set on the master project will be copied to branch project
  the only difference is that the branch project will be set to pull from the payload commit branch
* copying includes parameters for the job
  note that branch parameters will be unused but not removed from job definition
* the new project name is constructed like this:
  * if using master project name, "#{master project name}\_#{branch name}"
  * else "#{repo name from payload}\_#{branch name}"
* read the delete commit section below to see how branch deletion reflects this use case

Advantages of this approach:

* Jenkins can resolve dependencies between Maven projects automatically because Jenkins projects reference a single branch
* job / branch monitoring is easier because a Jenkins project is related to a single branch
* builds all branches

Disadvantages:

* multiple Jenkins project per Git(lab) repository
* concurrent builds occur for the same Git(lab) repository
* job / branch monitoring is not easy because of a large number of projects for a single Git(lab) repository

### Notify commit hook

Add this web hook on your Gitlab project: 

```
http://your-jenkins-server/gitlab/notify_commit
```

The procedure is the same as for the build now hook, the difference is that this hook schedules polling of the project, much like the original notifyCommit.

Additional notes:

* the project must be configured not to skip notifyCommit
* parametrized projects can be polled, but subsequent build will use the default parametere values (can't propagate the branch to the polling)

### Delete branch commits

In case Gitlab is triggering the deletion of a branch, the plugin will skip processing entirely unless automatic branch projects creation is enabled.
In that case, it will find the Jenkins project for that branch and delete it.
This applies only to non master branches (master is defined in plugin configuration).
Master branch project is never deleted.

### Hook data related

Gitlab uses JSON POST to send the information to the defined hook.
The plugin expects the request to have the appropriate structure, like this example:

```json
{
        :before => "95790bf891e76fee5e1747ab589903a6a1f80f22",
         :after => "da1560886d4f094c3e6c9ef40349f7d38b5d27d7",
           :ref => "refs/heads/master",
       :user_id => 4,
     :user_name => "John Smith",
    :repository => {
               :name => "Diaspora",
                :url => "localhost/diaspora",
        :description => "",
           :homepage => "localhost/diaspora",
            :private => true
    },
       :commits => [
        [0] {
                   :id => "450d0de7532f8b663b9c5cce183b...",
              :message => "Update Catalan translation to e38cb41.",
            :timestamp => "2011-12-12T14:27:31+02:00",
                  :url => "http://localhost/diaspora/commits/450d0de7532f...",
               :author => {
                 :name => "Jordi Mallach",
                :email => "jordi@softcatala.org"
            }
        },

        ....

        [3] {
                   :id => "da1560886d4f094c3e6c9ef40349...",
              :message => "fixed readme",
            :timestamp => "2012-01-03T23:36:29+02:00",
                  :url => "http://localhost/diaspora/commits/da1560886d...",
               :author => {
                 :name => "gitlab dev user",
                :email => "gitlabdev@dv6700.(none)"
            }
        }
    ],
   total_commits_count => 3
}
```

## Dependencies

* [Ruby runtime](https://github.com/jenkinsci/jenkins.rb) version 0.10 or higher
* [Git plugin](https://wiki.jenkins-ci.org/display/JENKINS/Git+Plugin) version 1.1.24 or higer


## Logging

In case you might wan't to inspect hook triggering (e.g. to check payload data), you can setup logging in Jenkins as [usual](https://wiki.jenkins-ci.org/display/JENKINS/Logging).
Just add a new logger for **Class** (this is because of JRuby internals).
