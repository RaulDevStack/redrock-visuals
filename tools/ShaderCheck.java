import org.lwjgl.glfw.GLFW;
import org.lwjgl.opengl.GL;
import org.lwjgl.opengl.GL20;

import java.nio.file.*;
import java.util.*;

/** Compila y enlaza cada pareja .vsh/.fsh de un directorio con el driver real (perfil compatibility). */
public class ShaderCheck {
    public static void main(String[] args) throws Exception {
        Path dir = Paths.get(args[0]);
        if (!GLFW.glfwInit()) throw new RuntimeException("glfwInit");
        GLFW.glfwWindowHint(GLFW.GLFW_VISIBLE, GLFW.GLFW_FALSE);
        GLFW.glfwWindowHint(GLFW.GLFW_CONTEXT_VERSION_MAJOR, 3);
        GLFW.glfwWindowHint(GLFW.GLFW_CONTEXT_VERSION_MINOR, 3);
        GLFW.glfwWindowHint(GLFW.GLFW_OPENGL_PROFILE, GLFW.GLFW_OPENGL_COMPAT_PROFILE);
        long win = GLFW.glfwCreateWindow(64, 64, "check", 0, 0);
        GLFW.glfwMakeContextCurrent(win);
        GL.createCapabilities();
        System.out.println("GL: " + org.lwjgl.opengl.GL11.glGetString(org.lwjgl.opengl.GL11.GL_RENDERER));

        TreeSet<String> names = new TreeSet<>();
        try (var s = Files.list(dir)) {
            s.forEach(p -> {
                String n = p.getFileName().toString();
                if (n.endsWith(".vsh")) names.add(n.substring(0, n.length() - 4));
            });
        }
        int errors = 0;
        for (String n : names) {
            int vs = compile(GL20.GL_VERTEX_SHADER, dir.resolve(n + ".vsh"), n + ".vsh");
            int fs = compile(GL20.GL_FRAGMENT_SHADER, dir.resolve(n + ".fsh"), n + ".fsh");
            if (vs == 0 || fs == 0) { errors++; continue; }
            int prog = GL20.glCreateProgram();
            GL20.glAttachShader(prog, vs);
            GL20.glAttachShader(prog, fs);
            GL20.glLinkProgram(prog);
            if (GL20.glGetProgrami(prog, GL20.GL_LINK_STATUS) == 0) {
                errors++;
                System.out.println("LINK FAIL " + n + ":\n" + GL20.glGetProgramInfoLog(prog));
            }
        }
        System.out.println(errors == 0 ? "ALL OK (" + names.size() + " programs)" : "ERRORS: " + errors);
        GLFW.glfwTerminate();
        System.exit(errors == 0 ? 0 : 1);
    }

    static int compile(int type, Path p, String label) throws Exception {
        int sh = GL20.glCreateShader(type);
        GL20.glShaderSource(sh, Files.readString(p));
        GL20.glCompileShader(sh);
        if (GL20.glGetShaderi(sh, GL20.GL_COMPILE_STATUS) == 0) {
            System.out.println("COMPILE FAIL " + label + ":\n" + GL20.glGetShaderInfoLog(sh));
            return 0;
        }
        String log = GL20.glGetShaderInfoLog(sh).trim();
        if (!log.isEmpty()) System.out.println("warn " + label + ": " + log);
        return sh;
    }
}
