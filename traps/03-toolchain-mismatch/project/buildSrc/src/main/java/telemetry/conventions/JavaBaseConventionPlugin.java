package telemetry.conventions;

import org.gradle.api.Plugin;
import org.gradle.api.Project;
import org.gradle.api.plugins.JavaPluginExtension;
import org.gradle.api.tasks.compile.JavaCompile;
import org.gradle.jvm.toolchain.JavaLanguageVersion;

/**
 * Settings that every module of the telemetry build shares.
 */
public class JavaBaseConventionPlugin implements Plugin<Project> {

    @Override
    public void apply(Project project) {
        project.getPluginManager().apply("java");

        int toolchain = intProperty(project, "telemetry.toolchain");

        JavaPluginExtension java = project.getExtensions().getByType(JavaPluginExtension.class);
        java.getToolchain().getLanguageVersion().set(JavaLanguageVersion.of(toolchain));

        project.getTasks().withType(JavaCompile.class).configureEach(task -> {
            task.getOptions().setEncoding("UTF-8");
            task.getOptions().getCompilerArgs().add("-parameters");
        });
    }

    static int intProperty(Project project, String name) {
        return Integer.parseInt(project.getProviders().gradleProperty(name).get().trim());
    }
}
