package telemetry.conventions;

import org.gradle.api.Plugin;
import org.gradle.api.Project;
import org.gradle.api.tasks.compile.JavaCompile;

/**
 * Settings for the modules that go into the collector distribution.
 */
public class LibraryConventionPlugin implements Plugin<Project> {

    @Override
    public void apply(Project project) {
        project.getPluginManager().apply("telemetry.java-base");
        project.getPluginManager().apply("java-library");

        int accepted = JavaBaseConventionPlugin.intProperty(project, "telemetry.collectorRuntime");

        project.getTasks().withType(JavaCompile.class)
                .configureEach(task -> task.getOptions().getRelease().set(accepted));
    }
}
