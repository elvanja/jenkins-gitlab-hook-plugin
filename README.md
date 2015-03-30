# Jenkins GitLab Hook Plugin

Enables GitLab web hooks to be used to trigger SMC polling on GitLab projects<br/>
Plugin details can be found at https://wiki.jenkins-ci.org/display/JENKINS/Gitlab+Hook+Plugin

## Why?

For [GitLab](https://about.gitlab.com) there is an existing solution that might work for you.<br/>
You can just use the notifyCommit hook on [Git plugin](https://wiki.jenkins-ci.org/display/JENKINS/Git+Plugin) like this:

```
http://your-jenkins-server/git/notifyCommit?url=<URL of the Git repository for the GitLab project>
```

But, with a large number of projects that are mostly polling (no hooks), the project might actually be built with a great delay (5 to 20 minutes).<br/>
You can find more details about notifyCommit and this issue [here](http://kohsuke.org/2011/12/01/polling-must-die-triggering-jenkins-builds-from-a-git-hook).

That is where this plugin comes in.<br/>
It gives you the option to use build\_now or notify\_commit hook, whichever suits your needs better.

### Build now hook

Add this web hook on your GitLab project:

```
http://your-jenkins-server/gitlab/build_now
```

Plugin will parse the GitLab payload and extract the branch for which the commit is being pushed and changes made.<br/>
It will then scan all Git projects in Jenkins and start the build for those that:

* match url of the GitLab repo
* match the configured refspec pattern if any
* and match committed GitLab branch

Notes:

* for branch comparison, it will take into account both the branch definition and the strategy (this is different from the original notifyCommit)
* the project must be enabled
* you don't have to setup polling for the project

#### Parameterized projects

The plugin will recognize projects that are parametrized and will use payload data to fill their values.<br/>
Only String and Choice parameter types are supported at this moment, all others are passed on with their defaults.<br/>
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
2. for builds per commit using the GitLab build now hook, the branch parameter will be filled in with the commit branch extracted from the payload sent from GitLab

Advantages of this approach:

* one Jenkins project per GitLab repository
* builds all branches
* no concurrent builds occur for the same GitLab repository

Disadvantages:

* Jenkins can't resolve dependencies between Maven projects automatically because Jenkins projects reference different branches at different times
* job / branch monitoring is not easy because all builds are contained within the same Jenkins project

### Notify commit hook

**NOTE:** the notify commit feature is considered deprecated, and will be removed on a future version.

Add this web hook on your GitLab project:

```
http://your-jenkins-server/gitlab/notify_commit
```

The procedure is the same as for the build now hook, the difference is that this hook schedules polling of the project, much like the original notifyCommit.

### Additional notes

This goes for both hooks:

* the project must be configured not to skip notifyCommit
* parametrized projects can be polled, but subsequent build will use the default parameter values (can't propagate the branch to the polling)

### Delete branch commits

In case GitLab is triggering the deletion of a branch, the plugin will skip processing entirely unless automatic branch projects creation is enabled.<br/>
In that case, it will find the Jenkins project for that branch and delete it.<br/>
This applies only to non master branches (master is defined in plugin configuration).<br/>
Master branch project is never deleted.

### Hook data related

GitLab uses JSON POST to send the information to the defined hook.<br/>
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
    "url": "git@example.com:diaspora/diaspora.git",
    "description": "",
    "homepage": "http://example.com/diaspora/diaspora",
    "private": true
  },
  "commits": [
    {
      "id": "b6568db1bc1dcd7f8b4d5a946b0b91f9dacd7327",
      "message": "Update Catalan translation to e38cb41.",
      "timestamp": "2011-12-12T14:27:31+02:00",
      "url": "http://example.com/diaspora/diaspora/commits/b6568db1bc1dcd7f8b4d5a946b0b91f9dacd7327",
      "author": {
        "name": "John Smith",
        "email": "jsmith@example.com"
      }
    },
    {
      "id": "da1560886d4f094c3e6c9ef40349f7d38b5d27d7",
      "message": "fixed readme",
      "timestamp": "2012-01-03T23:36:29+02:00",
      "url": "http://example.com/diaspora/diaspora/commits/da1560886d4f094c3e6c9ef40349f7d38b5d27d7",
      "author": {
        "name": "John Smith the Second",
        "email": "jsmith2@example.com"
      }
    }
  ],
  "total_commits_count": 2
}
```

## Building tags

Although tags are static entities and as such seem unsensible in anything
_continuos_, there are many scenarios where you would like to get some job done
by jenkins when _any_ tag is pushed to GitLab. The main problem to accomplish this
task is that wildcard handling by git plugin does not cover `refs/tags/*`, and
we need specific extensions to handle this use case.

When incoming payload comes from the creation of a tag, the plugin parses the
tag name and assings it to variable **TAGNAME**, that can be used on a parametrized
job. So, setting the branch specifier to `'refs/tags/${TAGNAME}'` the job will be
executed for every tag.

## Automatic project creation

### Create project for pushed branches

In case you might want to approach multiple branches by having a separate Jenkins project for each GitLab repository, you can turn on the appropriate plugin option. When enabled, if exists a Jenkins project that exactly maches the commited branch that project is build, and if no project exactly matches the commited branch, the plugin will

1. copy the master project
2. name the project according to the repository and commited branch name
3. adjust SCM settings to reflect the commited branch and repository
4. build the new project

Notes:

* above mentioned "master" can be one of the following (determined in given order):
  * project that references the given repo url and master branch configured for plugin (defaults to "master")
  * project that references the given repo url for any other branch
* a "master" project for the given repo is required to copy git settings, although templates functionality described below allow creation of jenkins projects for new projects
* everything you set on the master project will be copied to branch project, except that the copied project will track the payload commit branch and the project description, which is set based on plugin configuration
* copying includes all parameters for the job. Note that branch parameters will be unused but not removed from job definition
* the new project name is suffixed with the branch name, and depending on the value of "using master project name" configuration
ng whether "using master project name" is enabled on plugin configuration
* the new project name is constructed differently depending whether "using master project name" is enabled on plugin configuration, the first part will be the master project name or the repository name taken from payload
* these projects will be automatically deleted if the tracking branch is deleted, as far as the project description is in sync with the one configured in the plugin

Advantages of this approach:

* Jenkins can resolve dependencies between Maven projects automatically because Jenkins projects reference a single branch
* job / branch monitoring is easier because a Jenkins project is related to a single branch
* builds all branches

Disadvantages:

* multiple Jenkins project per GitLab repository
* concurrent builds occur for the same GitLab repository
* job / branch monitoring is not easy because of a large number of projects for a single GitLab repository

For this option to become active, just turn it on in Jenkins global configuration.

### Templates for unknown repositories

The plugin can be configured to automatically create projects when the hook is
activated by a GitLab repo unknown to jenkins. The template must be an existing
jenkins project, that could be an already running one or be spefically created
for this purpose. The template can be a disabled project, because the brand
new project will be enabled on creation. To enable this feature is enough to
supply values under the 'Advanced' part of the plugin section in the jenkins
global configuration page.


The simplest case is the *last resort template*, where a single template is
used for every input webhook for an unknown projec. To get finer clasification, distinct templates
can also be assigned to different GitLab groups, which can be useful, for
example, to handle android development based on gradle projects while the
remaining java repositories are created with a maven template. Group matching
is done using the exact group name.

The finest grained templating can be achieved with the repository name. It can
be applied if you have in use some naming scheme for those repos. Payload for
projects whose name starts with *lib-java-* could be redirected to a template
that is prepared to publish the artifact on a public maven repository. Matching
for this case is done based on leading text of the repository name.

### Building of merge requests

The plugin is able to automatically create and delete projects for merge
requests issued on GitLab. This behaviour is enabled by default, although it
can be switched off in the global Jenkins configuration. If there is a project
configured to build the target branch, a new project is created based on it,
setting the _branch specification_ with the merge request source branch, and
properly enabling _merge to_ option. Once created, any push to either source or
target branch will cause a build of the project, which is named based on the
original project and the merged branch, joined with _"-mr-"_ for easy
identification.

## Dependencies

* [Ruby runtime](https://github.com/jenkinsci/jenkins.rb) version 0.12 or higher
* [Git plugin](https://wiki.jenkins-ci.org/display/JENKINS/Git+Plugin) version 2.0 or higher


## Logging

In case you might want to inspect hook triggering (e.g. to check payload data), you can setup logging in Jenkins as [usual](https://wiki.jenkins-ci.org/display/JENKINS/Logging).<br/>
Just add a new logger for **Class** (this is because of JRuby internals).

## Testing

To help with testing, the spec/lib directory contains all the Java dependencies the plugin uses directly.
The spec_helper loads them before each test run. The package Rakefile behaviour
changes depending on the platform used to run it. When executed under jruby, it
runs the standard rspec examples, but when run on plain ruby starts a jenkins
instance and executes the acceptance tests.

No special options are required to execute the test on recent JRuby versions (such as 1.7.18)

