package models;

import hudson.Extension;
import hudson.model.UnprotectedRootAction;

/**
 * @author Jakub Jirutka <jakub@jirutka.cz>
 */
@Extension
public class GitlabUnprotectedRootAction implements UnprotectedRootAction {

    public String getIconFileName() {
        return null;
    }

    public String getDisplayName() {
        return "Unprotect path /gitlab";
    }

    public String getUrlName() {
        return "gitlab";
    }
}
