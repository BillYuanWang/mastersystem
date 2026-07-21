#if os(iOS)
import MasterDanceCore
import SwiftUI

@MainActor
struct MobileMemberGrowthView: View {
    let model: AppModel
    @Binding var selectedStudentID: StudentID?

    var body: some View {
        List {
            ContentUnavailableView(
                "暂无成长记录",
                systemImage: "chart.line.uptrend.xyaxis",
                description: Text("照片和老师评语发布后会显示在这里。")
            )
            .listRowBackground(Color.clear)
        }
        .listStyle(.insetGrouped)
        .navigationTitle("成长")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                MobileStudentPicker(students: model.students, selection: $selectedStudentID)
            }
        }
        .refreshable { await model.refreshFromCloud() }
    }
}
#endif
