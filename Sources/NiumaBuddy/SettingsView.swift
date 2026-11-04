import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: ConfigStore
    @ObservedObject var holidays: HolidayStore
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        let calc = WorkCalculator(config: store.config, holidays: holidays.table)
        let today = Date()

        Form {
            Section("薪资") {
                TextField("月薪（元）", value: $store.config.monthlySalary, format: .number.precision(.fractionLength(0...2)))
                Picker("日薪折算", selection: $store.config.payDayMode) {
                    Text("按法定 21.75 天").tag(PayDayMode.legal)
                    Text("按本月实际工作日").tag(PayDayMode.actual)
                }
                LabeledContent("折算结果") {
                    Text("日薪 ¥\(Fmt.money2(calc.dailyPay(on: today)))  ·  时薪 ¥\(Fmt.money2(calc.perSecond(on: today) * 3600))")
                        .monospacedDigit()
                }
                if store.config.monthlySalary <= 0 {
                    warning("填上月薪，计价器才会开始跳。")
                }
            }

            Section("作息") {
                DatePicker("上班时间", selection: minuteBinding(\.startMinute), displayedComponents: .hourAndMinute)
                DatePicker("下班时间", selection: minuteBinding(\.endMinute), displayedComponents: .hourAndMinute)
                Toggle("中午有午休（不计薪）", isOn: $store.config.lunchEnabled)
                if store.config.lunchEnabled {
                    DatePicker("午休开始", selection: minuteBinding(\.lunchStartMinute), displayedComponents: .hourAndMinute)
                    DatePicker("午休结束", selection: minuteBinding(\.lunchEndMinute), displayedComponents: .hourAndMinute)
                }
                LabeledContent("每天计薪") {
                    Text("\(Fmt.number(calc.config.dailyWorkSeconds / 3600)) 小时")
                        .monospacedDigit()
                }
                if !store.config.scheduleIsValid {
                    warning("下班时间要晚于上班时间（暂不支持跨零点的夜班）。")
                } else if store.config.lunchEnabled && !store.config.lunchIsValid {
                    warning("午休要落在上下班之间、且结束晚于开始；现在先按没有午休计算。")
                }
            }

            Section {
                WeekdayPicker(selection: $store.config.workdays)
                if store.config.workdays.isEmpty {
                    warning("至少选一天工作日。")
                }
                Toggle("自动跟随法定节假日和调休", isOn: $store.config.followHolidays)
                if store.config.followHolidays {
                    ForEach(holidays.trackedYears, id: \.self) { year in
                        LabeledContent("\(String(year)) 年安排") {
                            Text(holidayStatus(year))
                        }
                    }
                    HStack(spacing: 8) {
                        if let error = holidays.lastError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        Spacer()
                        if holidays.isChecking {
                            ProgressView().controlSize(.small)
                        }
                        Button("立即检查更新") { holidays.refresh() }
                            .disabled(holidays.isChecking)
                    }
                }
            } header: {
                Text("工作日")
            } footer: {
                Text(store.config.followHolidays
                     ? "放假的日子不上班、调休补班的周末照常上班，其余日子按上面勾选的星期。安排整理自国务院办公厅每年的放假通知，新一年的公布后会自动下载。"
                     : "只按上面勾选的星期上班。")
            }

            Section {
                ForEach($store.config.wishes) { $wish in
                    HStack(spacing: 8) {
                        TextField("名称", text: Binding(
                            get: { $wish.name.wrappedValue },
                            set: { $wish.name.wrappedValue = String($0.prefix(WorkConfig.maxWishNameLength)) }
                        ), prompt: Text("比如：一杯奶茶"))
                        .labelsHidden()
                        TextField("价格", value: $wish.price, format: .number.precision(.fractionLength(0...2)), prompt: Text("价格"))
                            .labelsHidden()
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("元").foregroundStyle(.secondary)
                        Button {
                            store.config.wishes.removeAll { $0.id == wish.id }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                        .help("删除这一项")
                    }
                }
                HStack {
                    Button {
                        store.config.wishes.append(WishItem(name: "新心愿", price: 100))
                    } label: {
                        Label("添加一项", systemImage: "plus")
                    }
                    .disabled(store.config.wishes.count >= WorkConfig.maxWishes)
                    Spacer()
                    Button("恢复默认清单") {
                        store.config.wishes = WishItem.defaults
                    }
                }
                .buttonStyle(.borderless)
            } header: {
                Text("心愿清单")
            } footer: {
                Text("上班时会提示「再过多久，就能把下一项赚回来」。名称里带上量词读起来更顺，比如「一件 T 恤」。")
            }

            Section {
                Toggle("显示桌宠", isOn: $store.config.petEnabled)
                if store.config.petEnabled {
                    Picker("形象", selection: $store.config.petSkin) {
                        Text("小铜板").tag(PetSkin.coin)
                        Text("浩浩（布偶猫）").tag(PetSkin.haohao)
                        Text("球球（黑猫）").tag(PetSkin.qiuqiu)
                        Text("薯条（金渐层）").tag(PetSkin.shutiao)
                    }
                    Picker("大小", selection: $store.config.petSize) {
                        Text("小").tag(PetSize.small)
                        Text("中").tag(PetSize.medium)
                        Text("大").tag(PetSize.large)
                    }
                    .pickerStyle(.segmented)
                    Toggle("浮在其他窗口前面", isOn: $store.config.petOnTop)
                    HStack {
                        Spacer()
                        Button("把\(store.config.petSkin.name)放回右下角") {
                            NotificationCenter.default.post(name: .resetPetPosition, object: nil)
                        }
                    }
                }
            } header: {
                Text("桌宠")
            } footer: {
                Text("单击它聊两句，双击打开面板，按住可以拖到别处，右键有带薪如厕和喝水记录。")
            }

            Section {
                Toggle("久坐提醒", isOn: $store.config.sitReminder)
                if store.config.sitReminder {
                    Picker("连续坐满", selection: $store.config.sitMinutes) {
                        ForEach(WorkConfig.reminderMinuteChoices, id: \.self) { Text("\($0) 分钟").tag($0) }
                    }
                }
                Toggle("喝水提醒", isOn: $store.config.waterReminder)
                if store.config.waterReminder {
                    Picker("上班时每隔", selection: $store.config.waterMinutes) {
                        ForEach(WorkConfig.reminderMinuteChoices, id: \.self) { Text("\($0) 分钟").tag($0) }
                    }
                }
                Toggle("下班提醒（下班前 10 分钟和下班时）", isOn: $store.config.remindOffWork)
            } header: {
                Text("健康提醒")
            } footer: {
                Text("久坐：中间离开电脑超过 5 分钟就重新计时。喝水：只在上班时段提醒，右键桌宠选「我喝了一杯水」会重新计时。提醒会弹系统通知，桌宠也会做动作；收不到通知的话，到「系统设置 → 通知」里允许牛马搭子。")
            }

            Section {
                Toggle("统计义务加班", isOn: $store.config.trackOvertime)
            } header: {
                Text("趣味统计")
            } footer: {
                Text("下班后键盘鼠标还在动就计入义务加班，离开超过 2 分钟不算。只在工作日统计，第二天清零。")
            }

            Section("通用") {
                Toggle("菜单栏显示今日已赚", isOn: $store.config.showAmountInMenuBar)
                Toggle("登录 Mac 时自动启动", isOn: Binding(get: { launchAtLogin }, set: setLaunchAtLogin))
                if let loginError {
                    warning(loginError)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 640)
    }

    private func holidayStatus(_ year: Int) -> String {
        guard let data = holidays.years[year], data.isPublished else {
            return "还没公布，公布后自动更新"
        }
        if let fetched = data.fetchedAt {
            return "已载入 · \(Fmt.monthDay(fetched))在线更新"
        }
        return "已载入 · 内置数据"
    }

    private func warning(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.callout)
            .foregroundStyle(.orange)
    }

    /// 配置里存的是「从 0 点起的分钟数」，DatePicker 要的是 Date
    private func minuteBinding(_ keyPath: WritableKeyPath<WorkConfig, Int>) -> Binding<Date> {
        Binding(
            get: {
                let minute = min(max(store.config[keyPath: keyPath], 0), 24 * 60 - 1)
                return Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                store.config[keyPath: keyPath] = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            }
        )
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginError = nil
        } catch {
            loginError = "设置失败：\(error.localizedDescription)。把 App 放进「应用程序」文件夹后再试。"
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}

struct WeekdayPicker: View {
    @Binding var selection: Set<Int>

    private let order = [2, 3, 4, 5, 6, 7, 1]
    private let names = [1: "日", 2: "一", 3: "二", 4: "三", 5: "四", 6: "五", 7: "六"]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(order, id: \.self) { day in
                let on = selection.contains(day)
                Button {
                    if on { selection.remove(day) } else { selection.insert(day) }
                } label: {
                    Text(names[day] ?? "")
                        .font(.callout.weight(.medium))
                        .frame(width: 36, height: 28)
                        .background(Capsule().fill(on ? Theme.amberDeep : Color.primary.opacity(0.07)))
                        .foregroundStyle(on ? Color.white : Color.primary)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}
