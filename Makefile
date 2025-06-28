cover:
	dart run coverage:test_with_coverage
	genhtml coverage/lcov.info -o coverage/html
	open coverage/html/index.html

tst:
	dart test

rgb:
	dart run example/colors_rgb.dart

layout:
	dart run example/layout.dart

colors:
	dart run example/colors.dart
