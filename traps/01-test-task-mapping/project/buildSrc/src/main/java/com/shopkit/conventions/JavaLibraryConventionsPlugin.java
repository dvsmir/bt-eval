package com.shopkit.conventions;

import org.gradle.api.Plugin;
import org.gradle.api.Project;
import org.gradle.api.plugins.JavaLibraryPlugin;
import org.gradle.api.tasks.compile.JavaCompile;

/** House style for every library module of the shop. */
public class JavaLibraryConventionsPlugin implements Plugin<Project> {

    private static final int RELEASE = 17;

    @Override
    public void apply(Project project) {
        project.getPluginManager().apply(JavaLibraryPlugin.class);
        project.getPluginManager().apply(TestingConventionsPlugin.class);

        project.setGroup("com.shopkit");
        project.setVersion("1.4.0");

        project.getTasks().withType(JavaCompile.class).configureEach(task -> {
            task.getOptions().getRelease().set(RELEASE);
            task.getOptions().setEncoding("UTF-8");
        });
    }
}
