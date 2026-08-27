package com.acme.conventions;

import java.util.Collections;

import org.gradle.api.Plugin;
import org.gradle.api.Project;
import org.gradle.api.artifacts.Configuration;
import org.gradle.api.artifacts.ConfigurationContainer;
import org.gradle.api.artifacts.dsl.DependencyHandler;
import org.gradle.api.plugins.JavaPlugin;
import org.gradle.api.tasks.testing.Test;
import org.gradle.api.tasks.testing.logging.TestExceptionFormat;

/**
 * Shared setup for every runnable service module of the ledger platform.
 *
 * <p>A service module applies this plugin and adds nothing else. The plugin gives it the
 * Java and application layout, the shared platform libraries, and the unit test
 * framework, so the module build file stays down to its own main class.
 */
public class ServiceConventionsPlugin implements Plugin<Project> {

    /** The bucket that collects the libraries that every service module shares. */
    private static final String PLATFORM_LIBS = "platformLibs";

    /** The configuration that the shared platform libraries flow into. */
    private static final String PLATFORM_SCOPE = JavaPlugin.COMPILE_ONLY_CONFIGURATION_NAME;

    private static final String PLATFORM_CORE_PATH = ":platform-core";

    private static final String JUNIT = "junit:junit:4.13.2";

    @Override
    public void apply(Project project) {
        project.getPluginManager().apply(JavaPlugin.class);
        project.getPluginManager().apply("application");

        project.setGroup("com.acme.ledger");
        project.setVersion("1.4.0");

        ConfigurationContainer configurations = project.getConfigurations();
        Configuration platformLibs = configurations.create(PLATFORM_LIBS);
        platformLibs.setDescription("Platform libraries that every service module shares.");
        platformLibs.setCanBeConsumed(false);
        platformLibs.setCanBeResolved(false);
        configurations.getByName(PLATFORM_SCOPE).extendsFrom(platformLibs);

        DependencyHandler dependencies = project.getDependencies();
        dependencies.add(
                PLATFORM_LIBS,
                dependencies.project(Collections.singletonMap("path", PLATFORM_CORE_PATH)));
        dependencies.add(JavaPlugin.TEST_IMPLEMENTATION_CONFIGURATION_NAME, JUNIT);

        project.getTasks().withType(Test.class).configureEach(test -> {
            test.useJUnit();
            test.setMaxParallelForks(1);
            test.getTestLogging().setExceptionFormat(TestExceptionFormat.FULL);
        });
    }
}
