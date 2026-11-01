package cn.heartgun.guanggu.controller;

import cn.heartgun.guanggu.common.ApiException;
import cn.heartgun.guanggu.common.Result;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

/**
 * 图片上传（F 阶段补齐）：活动封面等场景。
 * 存到工作目录下 uploads/（服务器 = /opt/guanggu/uploads），经 WebConfig
 * 的 /uploads/** 静态映射直接访问，返回相对 url 给前端拼域名。
 */
@RestController
public class UploadController {

    private final Path uploadDir;

    public UploadController() throws IOException {
        this.uploadDir = Paths.get(System.getProperty("user.dir")).resolve("uploads");
        Files.createDirectories(uploadDir);
    }

    /** multipart 字段名 file；仅收图片，返回 {url: "/uploads/xxx.jpg"} */
    @PostMapping("/api/upload")
    public Result<Map<String, Object>> upload(@RequestParam("file") MultipartFile file) throws IOException {
        if (file == null || file.isEmpty()) {
            throw new ApiException(400, "请选择要上传的图片");
        }
        String original = file.getOriginalFilename() == null ? "" : file.getOriginalFilename();
        String ext = ".jpg";
        String lower = original.toLowerCase();
        if (lower.endsWith(".png")) {
            ext = ".png";
        } else if (lower.endsWith(".webp")) {
            ext = ".webp";
        } else if (!lower.endsWith(".jpg") && !lower.endsWith(".jpeg")) {
            throw new ApiException(400, "仅支持 jpg / png / webp 图片");
        }
        if (file.getSize() > 5 * 1024 * 1024) {
            throw new ApiException(400, "图片不能超过 5MB");
        }
        String name = UUID.randomUUID().toString().replace("-", "") + ext;
        file.transferTo(uploadDir.resolve(name).toFile());
        Map<String, Object> out = new HashMap<>();
        out.put("url", "/uploads/" + name);
        return Result.ok(out);
    }
}
