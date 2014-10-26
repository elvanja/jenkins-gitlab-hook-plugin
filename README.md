# Jenkins Gitlab Hook Plugin

Enables Gitlab web hooks to be used to trigger SMC polling on Gitlab projects<br/>
Plugin details can be found at https://wiki.jenkins-ci.org/display/JENKINS/Gitlab+Hook+Plugin

## Why?

For [Gitlab](http://gitlabhq.com) there is an existing solution that might work for you.<br/>
You can just use the notifyCommit hook on [Git plugin](https://wiki.jenkins-ci.org/display/JENKINS/Git+Plugin) like this:

```
http://your-jenkins-server/git/notifyCommit?url=<URL of the Git repository for the Gitlab project>
```

But, with a large number of projects that are mostly polling (no hooks), the project might actually be built with a great delay (5 to 20 minutes).<br/>
You can find more details about notifyCommit and this issue [here](http://kohsuke.org/2011/12/01/polling-must-die-triggering-jenkins-builds-from-a-git-hook).

That is where this plugin comes in.<br/>
It gives you the option to use build\_now or notify\_commit hook, whichever suits your needs better.

### Build now hook

Add this web hook on your Gitlab project: 

```
http://your-jenkins-server/gitlab/build_now
```

Plugin will parse the Gitlab payload and extract the branch for which the commit is being pushed and changes made.<br/>
It will then scan all Git projects in Jenkins and start the build for those that:

* match url of the Gitlab repo
* match the configured refspec pattern if any
* and match committed Gitlab branch

Notes:

* for branch comparison, it will take into account both the branch definition and the strategy (this is different from the original notifyCommit)
* the project must be enabled
* you don't have to setup polling for the project

#### Parameterized projects

The plugin will recognize projects that are parametrized and will use payload data to fill their values.<br/>
Only String type of parameters are supported at this moment, all others are passed on with their defaults.<br/>
You can reference any data from the payload, including arrays and entire sections.<br/>
Here are a few examples:

| Name | Type | Default Value | Value In Build | Note |
| ------------- | ------------- | ------------- | ------------- | ------------- |
| TRIGGERED | Boolean | true | true | Not a String parameter, using default value |
| TRIGGERED_BY | String | N/A | N/A | Not found in payload or details, using default value |
| USER_NAME | String | Default User | John Smith | From payload, first level, not using the default value |
| REPOSITORY.HOMEPAGE | String | - | http://example.com/diaspora | From payload, nested value |
| COMMITS.0.MESSAGE | String | - | Update Catalan translation to e38cb41. | From payload, nested value from array |
| COMMITS.1 | String | - | { "id": "da1560886d4f...", ... } | From payload, entire value from array |
| COMMITS.1.AUTHOR.NAME | String | - | John Smith the Second | From payload, entire value from nested value in array |
| cOmMiTs.1.aUtHoR.nAme | String | - | John Smith the Second | As above, case insensitive |
| FULL_BRANCH_REFERENCE | String | - | refs/heads/master | From details |
| BRANCH | String | - | master | From details |

In case you define a parameter inside the branch specifier in Git configuration of the project, the plugin will replace the parameter value with the commit branch from the payload.<br/>
Replacing is done by matching **${PARAMETER\_KEY}** in the branch specifier to the parameter list for the project.<br/>

This is useful e.g. when you want to define a single project for all the branches in the repository.<br/>
Setup might look like this:

* parametrized build with string parameter **BRANCH\_TO\_BUILD**, default = master
* Source Code Management --> Branch specifier: **origin/${BRANCH\_TO\_BUILD}**

With this configuration, you have the following options:

1. you can start a manual Jenkins build of a project, and it will ask for a branch to build
2. for builds per commit using the Gitlab build now hook, the branch parameter will be filled in with the commit branch extracted from the payload sent from Gitlab

Advantages of this approach:

* one Jenkins project per Git(lab) repository
* builds all branches
* no concurrent builds occur for the same Git(lab) repository

Disadvantages:

* Jenkins can't resolve dependencies between Maven projects automatically because Jenkins projects reference different branches at different times
* job / branch monitoring is not easy because all builds are contained within the same Jenkins project

### Notify commit hook

Add this web hook on your Gitlab project: 

```
http://your-jenkins-server/gitlab/notify_commit
```

The procedure is the same as for the build now hook, the difference is that this hook schedules polling of the project, much like the original notifyCommit.

### Additional notes

This goes for both hooks:

* the project must be configured not to skip notifyCommit
* parametrized projects can be polled, but subsequent build will use the default parameter values (can't propagate the branch to the polling)

### Delete branch commits

In case Gitlab is triggering the deletion of a branch, the plugin will skip processing entirely unless automatic branch projects creation is enabled.<br/>
In that case, it will find the Jenkins project for that branch and delete it.<br/>
This applies only to non master branches (master is defined in plugin configuration).<br/>
Master branch project is never deleted.

### Hook data related

Gitlab uses JSON POST to send the information to the defined hook.<br/>
The plugin expects the request to have the appropriate structure, like this example:

```json
{
  "before": "95790bf891e76fee5e1747ab589903a6a1f80f22",
  "after": "da1560886d4f094c3e6c9ef40349f7d38b5d27d7",
  "ref": "refs/heads/master",
  "user_id": 4,
  "user_name": "John Smith",
  "project_id": 15,
  "repository": {
    "name": "Diaspora",
    "url": "git@example.com:diaspora.git",
    "description": "",
    "homepage": "http://example.com/diaspora"
  },
  "commits": [
    {
      "id": "b6568db1bc1dcd7f8b4d5a946b0b91f9dacd7327",
      "message": "Update Catalan translation to e38cb41.",
      "timestamp": "2011-12-12T14:27:31+02:00",
      "url": "http://example.com/diaspora/commits/b6568db1bc1dcd7f8b4d5a946b0b91f9dacd7327",
      "author": {
        "name": "John Smith",
        "email": "jsmith@example.com"
      }
    },
    {
      "id": "da1560886d4f094c3e6c9ef40349f7d38b5d27d7",
      "message": "fixed readme",
      "timestamp": "2012-01-03T23:36:29+02:00",
      "url": "http://example.com/diaspora/commits/da1560886d4f094c3e6c9ef40349f7d38b5d27d7",
      "author": {
        "name": "John Smith the Second",
        "email": "jsmith2@example.com"
      }
    }
  ],
  "total_commits_count": 2
}
```

## Automatic branch project creation

In case you might want to approach multiple branches by having a separate Jenkins project for each Git(lab) repository, you can turn on the appropriate plugin option.<br/>
This use case workflow:

* if exists a Jenkins project that exactly maches the commited branch
  * build the matching project
* else
  * copy the master project
  * name the project according to the repository and commited branch name
  * adjust SCM settings to reflect the commited branch and repository
  * build the new project

Notes:

* above mentioned "master" can be one of the following (determined in given order):
  * project that references the given repo url and master branch<br/>
    master branch name can be set in Jenkins main configuration, "master" is the default
  * project that references the given repo url for any other branch
* the master project for the given repo is required<br/>
  because this is currently the only way to copy git settings (e.g. you could use ssh or http access)
* everything you set on the master project will be copied to branch project<br/>
  the only difference is that the branch project will be set to pull from the payload commit branch
* copying includes parameters for the job<br/>
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

For this option to become active, just turn it on in Jenkins global configuration.

## Dependencies

* [Ruby runtime](https://github.com/jenkinsci/jenkins.rb) version 0.12 or higher
* [Git plugin](https://wiki.jenkins-ci.org/display/JENKINS/Git+Plugin) version 1.1.26 or higer


## Logging

In case you might want to inspect hook triggering (e.g. to check payload data), you can setup logging in Jenkins as [usual](https://wiki.jenkins-ci.org/display/JENKINS/Logging).<br/>
Just add a new logger for **Class** (this is because of JRuby internals).

## Contributing

### Testing

To help with testing, the spec/lib directory contains all the Java dependencies the plugin uses directly.
The spec_helper loads them before each test run.

In case you need to add new classes, please namespace them. See existing ones for details.

Then running JRuby to execute tests, you'll need the following switches:

* --1.9
* -Xcext.enabled=true
* -X+0
