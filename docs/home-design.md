# 홈 화면 디자인

- 승인된 화이트·인디고 시안의 무대 사진, 큰 안내 시작 버튼, 새 연습 카드, 최근 연습을 적용했습니다.
- 탐색·하단 탭·선택 창은 SwiftUI NavigationStack, TabView, List, sheet를 사용합니다. 기본 버튼 스타일과 SF Symbols, 시스템 글꼴을 적용했습니다.
- 설명 문구: “예술가의 움직임을 보여, 한발짝씩 함께해요”
- 최근 연습은 생성일 내림차순 최대 3개이며 사용 이력을 뜻하지 않습니다.
- 무대 사진은 모든 장면에 공통으로 쓰는 장식 이미지이며 실제 사용자의 공연장 사진이 아닙니다.

## 이미지 에셋

- 생성 도구: built-in image_gen
- 경로: StageCue/Resources/Assets.xcassets/StageHero.imageset/stage-hero.png
- 크기: 1672 × 941 PNG
- 원본을 변형하지 않고 에셋 카탈로그에 포함했습니다.

### 생성 프롬프트

Use case: photorealistic-natural. Asset type: landscape photographic hero image for an iOS stage rehearsal app. Primary request: create one beautifully quiet, empty rehearsal stage, a real modest theatre rehearsal space photographed with understated editorial realism. Warm wooden rehearsal stage floor with subtle grain and natural wear; a charcoal matte back wall; deep indigo theatre curtains at the far left and right edges. A tall window on the left admits gentle afternoon sunlight and casts long soft window shadows across the wooden floor. One simple wooden chair stands far right, off center. Keep the center of the stage empty, with generous open floor and uncluttered negative space. Composition/framing: wide horizontal landscape 16:9, frontal view at natural eye level, spacious stage filling the frame, moderate wide-angle lens without distorted lines. Lighting/mood: calm, welcoming, soft natural warm sunlight balanced against the cool charcoal wall and indigo curtains. Materials/textures: authentic wood, matte painted wall, woven heavy curtains. The result should look like an excellent real photograph rather than a 3D render. No people, no text, no lettering, no logos, no UI, no frames, no graphic overlays, no watermark, no spotlights, no extra furniture or props.
