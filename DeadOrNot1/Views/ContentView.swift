import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: CheckInStore

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("死了么")
                    .font(.largeTitle)
                    .bold()

                VStack {
                    Text("今日状态")
                    Text(store.isCheckedInToday() ? "已打卡 ✅" : "未打卡 ❌")
                        .font(.title2)
                        .foregroundColor(store.isCheckedInToday() ? .green : .red)
                }

                Button(action: {
                    store.checkInToday()
                }) {
                    Text(store.isCheckedInToday() ? "已打卡（已记录）" : "打卡")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(store.isCheckedInToday() ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(store.isCheckedInToday())

                HStack {
                    VStack(alignment: .leading) {
                        Text("当前连胜：")
                        Text("\(store.currentStreak()) 天").font(.title2).bold()
                    }
                    Spacer()
                }.padding()

                List {
                    Section(header: Text("打卡记录（最近）")) {
                        ForEach(store.dates.sorted(by: >), id: \.self) { d in
                            Text(d)
                        }
                    }
                }
            }
            .padding()
            .navigationTitle("首页")
        }
    }
}
