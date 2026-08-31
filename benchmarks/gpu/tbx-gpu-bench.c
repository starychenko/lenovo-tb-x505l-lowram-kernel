#include <EGL/egl.h>
#include <GLES2/gl2.h>

#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static const char *vertex_shader_source =
    "attribute vec2 a_position;\n"
    "varying vec2 v_position;\n"
    "void main() {\n"
    "  v_position = a_position;\n"
    "  gl_Position = vec4(a_position, 0.0, 1.0);\n"
    "}\n";

static const char *fragment_shader_source =
    "precision highp float;\n"
    "varying vec2 v_position;\n"
    "uniform float u_seed;\n"
    "void main() {\n"
    "  vec2 z = v_position;\n"
    "  vec2 c = vec2(0.285 + 0.01 * sin(u_seed), 0.01 + 0.01 * cos(u_seed));\n"
    "  float accumulator = 0.0;\n"
    "  for (int i = 0; i < 64; ++i) {\n"
    "    z = vec2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c;\n"
    "    accumulator += dot(z, z) * 0.0001;\n"
    "    z = fract(z * 0.5 + 0.5) * 2.0 - 1.0;\n"
    "  }\n"
    "  gl_FragColor = vec4(0.1 + 0.8 * fract(accumulator),\n"
    "                      0.1 + 0.8 * fract(accumulator * 0.7),\n"
    "                      0.1 + 0.8 * fract(accumulator * 0.3), 1.0);\n"
    "}\n";

static double monotonic_seconds(void)
{
    struct timespec value;

    if (clock_gettime(CLOCK_MONOTONIC, &value) != 0) {
        fprintf(stderr, "clock_gettime failed: %s\n", strerror(errno));
        exit(1);
    }

    return (double)value.tv_sec + (double)value.tv_nsec / 1000000000.0;
}

static GLuint compile_shader(GLenum type, const char *source)
{
    GLuint shader = glCreateShader(type);
    GLint status = GL_FALSE;

    glShaderSource(shader, 1, &source, NULL);
    glCompileShader(shader);
    glGetShaderiv(shader, GL_COMPILE_STATUS, &status);
    if (status != GL_TRUE) {
        char log[4096];
        GLsizei length = 0;

        glGetShaderInfoLog(shader, sizeof(log), &length, log);
        fprintf(stderr, "shader compilation failed: %.*s\n", (int)length, log);
        exit(1);
    }

    return shader;
}

static GLuint create_program(void)
{
    GLuint vertex_shader = compile_shader(GL_VERTEX_SHADER, vertex_shader_source);
    GLuint fragment_shader = compile_shader(GL_FRAGMENT_SHADER, fragment_shader_source);
    GLuint program = glCreateProgram();
    GLint status = GL_FALSE;

    glAttachShader(program, vertex_shader);
    glAttachShader(program, fragment_shader);
    glBindAttribLocation(program, 0, "a_position");
    glLinkProgram(program);
    glGetProgramiv(program, GL_LINK_STATUS, &status);
    if (status != GL_TRUE) {
        char log[4096];
        GLsizei length = 0;

        glGetProgramInfoLog(program, sizeof(log), &length, log);
        fprintf(stderr, "program link failed: %.*s\n", (int)length, log);
        exit(1);
    }

    glDeleteShader(vertex_shader);
    glDeleteShader(fragment_shader);
    return program;
}

static int parse_positive(const char *text, const char *name)
{
    char *end = NULL;
    long value = strtol(text, &end, 10);

    if (!text[0] || !end || *end || value <= 0 || value > 1000000) {
        fprintf(stderr, "invalid %s: %s\n", name, text);
        exit(2);
    }

    return (int)value;
}

int main(int argc, char **argv)
{
    const int width = argc > 1 ? parse_positive(argv[1], "width") : 768;
    const int height = argc > 2 ? parse_positive(argv[2], "height") : 768;
    const int frames = argc > 3 ? parse_positive(argv[3], "frames") : 120;
    const int warmup_frames = argc > 4 ? parse_positive(argv[4], "warmup frames") : 8;
    const EGLint config_attributes[] = {
        EGL_SURFACE_TYPE, EGL_PBUFFER_BIT,
        EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
        EGL_RED_SIZE, 8,
        EGL_GREEN_SIZE, 8,
        EGL_BLUE_SIZE, 8,
        EGL_ALPHA_SIZE, 8,
        EGL_NONE
    };
    const EGLint surface_attributes[] = {
        EGL_WIDTH, width,
        EGL_HEIGHT, height,
        EGL_NONE
    };
    const EGLint context_attributes[] = {
        EGL_CONTEXT_CLIENT_VERSION, 2,
        EGL_NONE
    };
    const GLfloat vertices[] = {
        -1.0f, -1.0f,
         3.0f, -1.0f,
        -1.0f,  3.0f
    };
    EGLDisplay display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
    EGLConfig config;
    EGLint config_count = 0;
    EGLSurface surface;
    EGLContext context;
    GLuint program;
    GLint seed_location;
    unsigned char pixel[4] = {0};
    double start;
    double elapsed;
    int frame;

    if (display == EGL_NO_DISPLAY || !eglInitialize(display, NULL, NULL)) {
        fprintf(stderr, "eglInitialize failed: 0x%x\n", eglGetError());
        return 1;
    }
    if (!eglChooseConfig(display, config_attributes, &config, 1, &config_count) ||
        config_count != 1) {
        fprintf(stderr, "eglChooseConfig failed: 0x%x\n", eglGetError());
        return 1;
    }

    surface = eglCreatePbufferSurface(display, config, surface_attributes);
    context = eglCreateContext(display, config, EGL_NO_CONTEXT, context_attributes);
    if (surface == EGL_NO_SURFACE || context == EGL_NO_CONTEXT ||
        !eglMakeCurrent(display, surface, surface, context)) {
        fprintf(stderr, "EGL context creation failed: 0x%x\n", eglGetError());
        return 1;
    }

    program = create_program();
    seed_location = glGetUniformLocation(program, "u_seed");
    glUseProgram(program);
    glViewport(0, 0, width, height);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, vertices);
    glEnableVertexAttribArray(0);

    printf("renderer=%s\n", glGetString(GL_RENDERER));
    printf("version=%s\n", glGetString(GL_VERSION));
    printf("workload=fragment-alu width=%d height=%d frames=%d warmup=%d iterations=64\n",
           width, height, frames, warmup_frames);

    for (frame = 0; frame < warmup_frames; ++frame) {
        glUniform1f(seed_location, (GLfloat)frame * 0.013f);
        glDrawArrays(GL_TRIANGLES, 0, 3);
        glFinish();
    }

    start = monotonic_seconds();
    for (frame = 0; frame < frames; ++frame) {
        glUniform1f(seed_location, (GLfloat)(frame + warmup_frames) * 0.013f);
        glDrawArrays(GL_TRIANGLES, 0, 3);
        /* Adreno is tile based and can discard overwritten pbuffer draws. */
        glFinish();
    }
    elapsed = monotonic_seconds() - start;
    glReadPixels(width / 3, height / 5, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, pixel);

    if (glGetError() != GL_NO_ERROR) {
        fprintf(stderr, "OpenGL error after workload\n");
        return 1;
    }

    printf("elapsed_ms=%.3f\n", elapsed * 1000.0);
    printf("frames_per_second=%.3f\n", (double)frames / elapsed);
    printf("megapixels_per_second=%.3f\n",
           ((double)width * (double)height * (double)frames) / elapsed / 1000000.0);
    printf("checksum=%u,%u,%u,%u\n", pixel[0], pixel[1], pixel[2], pixel[3]);

    glDeleteProgram(program);
    eglMakeCurrent(display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
    eglDestroyContext(display, context);
    eglDestroySurface(display, surface);
    eglTerminate(display);
    return 0;
}
