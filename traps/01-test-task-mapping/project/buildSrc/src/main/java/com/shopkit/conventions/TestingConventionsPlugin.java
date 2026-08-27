package com.shopkit.conventions;

import org.gradle.api.Plugin;
import org.gradle.api.Project;
import org.gradle.api.artifacts.ConfigurationContainer;
import org.gradle.api.plugins.JavaPlugin;
import org.gradle.api.plugins.JavaPluginExtension;
import org.gradle.api.tasks.SourceSet;
import org.gradle.api.tasks.SourceSetContainer;
import org.gradle.api.tasks.testing.Test;
import org.gradle.api.tasks.testing.logging.TestExceptionFormat;
import org.gradle.api.tasks.testing.logging.TestLogEvent;
import org.gradle.language.base.plugins.LifecycleBasePlugin;

/** House style for the test suites of every module of the shop. */
public class TestingConventionsPlugin implements Plugin<Project> {

    private static final String SUITE = "integrationTest";

    @Override
    public void apply(Project project) {
        project.getPluginManager().apply(JavaPlugin.class);

        project.getDependencies()
                .add(JavaPlugin.TEST_IMPLEMENTATION_CONFIGURATION_NAME, "junit:junit:4.13.2");

        SourceSetContainer sourceSets =
                project.getExtensions().getByType(JavaPluginExtension.class).getSourceSets();
        SourceSet main = sourceSets.getByName(SourceSet.MAIN_SOURCE_SET_NAME);
        SourceSet suite = sourceSets.create(SUITE);
        suite.setCompileClasspath(suite.getCompileClasspath().plus(main.getOutput()));
        suite.setRuntimeClasspath(suite.getRuntimeClasspath().plus(main.getOutput()));

        ConfigurationContainer configurations = project.getConfigurations();
        configurations.getByName(SUITE + "Implementation").extendsFrom(
                configurations.getByName(JavaPlugin.IMPLEMENTATION_CONFIGURATION_NAME),
                configurations.getByName(JavaPlugin.TEST_IMPLEMENTATION_CONFIGURATION_NAME));
        configurations.getByName(SUITE + "RuntimeOnly").extendsFrom(
                configurations.getByName(JavaPlugin.RUNTIME_ONLY_CONFIGURATION_NAME),
                configurations.getByName(JavaPlugin.TEST_RUNTIME_ONLY_CONFIGURATION_NAME));

        project.getTasks().register(SUITE, Test.class, task -> {
            task.setGroup(LifecycleBasePlugin.VERIFICATION_GROUP);
            task.setDescription("Runs the integration test suite.");
            task.setTestClassesDirs(suite.getOutput().getClassesDirs());
            task.setClasspath(suite.getRuntimeClasspath());
            task.shouldRunAfter(project.getTasks().named(JavaPlugin.TEST_TASK_NAME));
        });

        project.getTasks().withType(Test.class).configureEach(task -> {
            task.getTestLogging().setEvents(java.util.Set.of(TestLogEvent.FAILED));
            task.getTestLogging().setExceptionFormat(TestExceptionFormat.SHORT);
        });
    }
}
