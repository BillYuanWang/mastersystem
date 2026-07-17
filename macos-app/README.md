# MD Desk macOS App

双击 `MD Desk.app` 即可使用。它和 `web` 文件夹里的网页版本是并行关系，不互相依赖。

数据保存在同一层的 `MD Desk Data/courses.csv`。这个文件夹跟着 Dropbox 同步后，在另一台 Mac 上打开 app 会继续读取同一份课程数据。

不要把课程数据写进 `.app` 包内部：签名后的 app 包资源不适合被反复修改。现在的结构更适合 Dropbox 可移植使用。

如果另一台 Mac 第一次打开提示安全确认，可以右键点击 app，选择“打开”，确认一次即可。

`source` 文件夹是这个 app 的 SwiftPM 源码，后续继续改功能时会用到；平时使用只需要打开顶层的 app。
