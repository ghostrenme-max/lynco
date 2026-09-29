# LYNCO 3D 커튼 전환

`demo.tscn`을 Godot에서 열고 F6으로 재생합니다. 엔트리: `curtain_transition.tscn`.

```gdscript
var curtain = preload("res://effects/curtain_transition/curtain_transition.tscn").instantiate()
get_tree().root.add_child(curtain)
curtain.play()
# 화면 변경까지 수행할 때:
curtain.transition_to("res://scenes/your_scene.tscn")
```

## 최종 구현

블렌더 5.2 Cloth solver에서 두 장의 분리된 천을 함께 계산했습니다. 중력, 장력, 굽힘, 감쇠, 천끼리의 접촉은 같은 solver의 self-collision으로 처리합니다. 손잡이 부분은 레일보다 먼저 중앙으로 이동합니다. 닫힘과 열림 모두 시간 순서대로 별도로 시뮬레이션한 동작이며 역재생하지 않습니다.

중앙에서 눌릴 때 원단을 조금 더 밀어 넣어 주름을 모으고, 베이크 마지막 단계에 좌우 접촉면 제약을 적용해 서로 넘어가지 않도록 보정합니다. Solidify로 실제 두께를 생성했습니다. 131프레임 전체에서 좌우 정점이 중앙을 관통하지 않는 것을 수치 검증했습니다. 실시간 사용자 상호작용용 천 물리는 아니며, 정해진 화면 전환 연출입니다.

양쪽은 참고 이미지의 같은 삽화풍 적색 재질을 사용합니다. 원본의 다이아몬드·낡은 무늬를 유지하고 광택을 없앴습니다. 3D 법선에 따른 부드러운 명암만 더하며 조명에 따른 좌우 색 차이를 없앴습니다. 승인된 움직임 데이터는 변경하지 않았습니다. GPU가 미리 계산된 3D 정점 위치와 법선을 프레임 사이에서 보간합니다. 총 3,828정점, 위치·법선 데이터 약 11.48 MiB, 1920x1080 투명 3D 뷰포트입니다. 게임 실행 중 천 물리 시뮬레이션은 없으며 재생 종료 시 뷰포트 렌더링과 스크립트 갱신을 중지합니다. 텍스처·프레임버퍼·그림자 버퍼 메모리는 별도입니다.

완전히 닫힌 순간에는 미세한 봉제선 틈으로 다음 화면이 비치지 않도록 짙은 안감을 함께 표시합니다. `covered` 이후 다음 씬으로 변경합니다. 장면 리소스는 스레드 로딩하며, 중복 호출은 ERR_BUSY로 차단합니다.

블렌더 원본과 재생 가능한 베이크:
`C:/Users/user/Documents/ChatGPT/린코/curtain-webp/blender_bake/LYNCO_curtains_contact.blend`
재생용 shape key 메시와 원본 Cloth 설정을 함께 보관했습니다.

`speed`로 전체 속도를 조절합니다. 완전히 닫힌 상태에서 기본 1초 대기한 뒤 다시 열립니다. closed_hold_seconds로 대기 시간을 조절하며 이 시간은 speed와 독립적입니다. 기본 전체 재생 시간은 약 3.2초입니다. 실제 Godot 실행으로 장면 변경·리사이즈·일시정지·오버레이 유지·종료 후 정지를 검증합니다. 기존 게임 메뉴 버튼 연결은 변경하지 않았습니다.


