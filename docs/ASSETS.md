# Thay mẫu bằng tài sản Blender / glTF

Bản prototype dùng BoxMesh, CylinderMesh và vật liệu gốc tạo trong `scripts/world/hospital.gd`; không sử dụng tài sản thương mại hay hình ảnh tham khảo từ prompt. Không có NPC người được tuyên bố hoàn thành. Font có giấy phép được giữ kèm theo, âm thanh PCM gốc có thể tái tạo bằng `python3 tools/generate_audio.py`.

## Quy trình nhập mẫu

1. Trong Blender, dùng đơn vị mét; áp dụng scale/rotation, giữ pivot ở chân nhân vật hoặc chân đồ vật. Tạo vật liệu Principled BSDF đơn giản tương thích glTF, ưu tiên atlas 1024/2048 thay cho nhiều texture lớn.
2. Tạo mesh LOD và collision đơn giản riêng. Với nhân vật: rig có tên ổn định, clip idle/walk/run/crouch/inspect; dùng root motion hoặc chuyển động bằng controller nhất quán, tránh cả hai cùng di chuyển nhân vật.
3. Xuất **glTF 2.0 → GLB**, Selected Objects, UV/normals/animations, ghi credit/giấy phép cạnh asset. Không commit `.blend` như runtime dependency; Godot có thể nhập GLB mà không cần Blender trên máy chơi.
4. Lưu trong `assets/models/`, kéo GLB vào scene phụ kế thừa. Bật Generate LODs trong Import khi phù hợp; đặt mesh dưới node hình ảnh, collider và ID gameplay độc lập.
5. Thay các mesh trang trí ở `hospital.gd` hoặc chuyển khu vực sang scene `.tscn`. Giữ vị trí cửa, collider, điểm xuất hiện và `EvidenceObject.evidence_id`; không đặt một collider tường che mất vùng tương tác.
6. Kiểm tra ánh sáng Compatibility, silhouette, FPS/draw calls ở 720p; kiểm tra lại tầm với, chắn tia và đường đi bằng scene/gameplay tests.

Không xem bật LOD trong cấu hình là bằng chứng đã có các mesh LOD. Không xem software rendering trên cloud là benchmark Intel UHD. Tài sản người bán hiện thực, cử động mắt/mặt và lip sync thuộc giai đoạn sau.
