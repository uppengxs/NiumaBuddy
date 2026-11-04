import Combine
import Foundation

struct HolidayDay: Codable, Equatable {
    /// yyyy-MM-dd
    var date: String
    var name: String
    /// true = 放假；false = 调休补班
    var isOffDay: Bool
}

/// 一年的放假调休安排；days 为空表示国务院还没公布这一年
struct HolidayYear: Codable, Equatable {
    var year: Int
    var days: [HolidayDay]
    /// 在线下载的时间；内置数据为 nil
    var fetchedAt: Date?

    var isPublished: Bool { !days.isEmpty }
}

struct HolidayTable {
    static let empty = HolidayTable(years: [])

    let years: [Int: HolidayYear]
    /// 每段连续放假的第一天（按日期排序），用来算「元旦假期还有几天」
    let offBlocks: [HolidayDay]
    private let byDate: [String: HolidayDay]

    init(years: [HolidayYear]) {
        var byYear: [Int: HolidayYear] = [:]
        var byDate: [String: HolidayDay] = [:]
        for year in years {
            byYear[year.year] = year
            for day in year.days { byDate[day.date] = day }
        }
        self.years = byYear
        self.byDate = byDate

        // yyyy-MM-dd 按字符串排序就是按日期排序；同名的放假日之间不隔补班就算一段
        var blocks: [HolidayDay] = []
        var previous: HolidayDay?
        for day in byDate.values.sorted(by: { $0.date < $1.date }) {
            if day.isOffDay && (previous?.isOffDay != true || previous?.name != day.name) {
                blocks.append(day)
            }
            previous = day
        }
        offBlocks = blocks
    }

    func day(on date: Date, calendar: Calendar) -> HolidayDay? {
        guard !byDate.isEmpty else { return nil }
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return byDate[String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)]
    }
}

enum HolidayParser {
    static let maxBytes = 256 * 1024
    static let maxDays = 120
    static let maxNameLength = 20

    /// holiday-cn 的文件格式（只取用得到的字段）
    private struct Remote: Decodable {
        let year: Int
        let days: [HolidayDay]
    }

    /// 解析下载回来的 JSON；任何一处不合法就整份丢弃
    static func parse(_ data: Data, expectedYear: Int) -> HolidayYear? {
        guard data.count <= maxBytes,
              let remote = try? JSONDecoder().decode(Remote.self, from: data) else { return nil }
        return validated(HolidayYear(year: remote.year, days: remote.days), expectedYear: expectedYear)
    }

    static func validated(_ input: HolidayYear, expectedYear: Int) -> HolidayYear? {
        guard input.year == expectedYear, input.days.count <= maxDays else { return nil }
        var days: [HolidayDay] = []
        for day in input.days {
            let name = day.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard isValidDate(day.date, near: expectedYear), !name.isEmpty, name.count <= maxNameLength else { return nil }
            days.append(HolidayDay(date: day.date, name: name, isOffDay: day.isOffDay))
        }
        var result = input
        result.days = days
        return result
    }

    private static func isValidDate(_ text: String, near year: Int) -> Bool {
        let chars = Array(text)
        guard chars.count == 10 else { return false }
        for (i, c) in chars.enumerated() {
            let ok = (i == 4 || i == 7) ? c == "-" : ("0"..."9").contains(c)
            if !ok { return false }
        }
        guard let y = Int(String(chars[0..<4])), let m = Int(String(chars[5..<7])), let d = Int(String(chars[8..<10])),
              abs(y - year) <= 1 else { return false }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        guard let date = cal.date(from: DateComponents(year: y, month: m, day: d)) else { return false }
        let back = cal.dateComponents([.year, .month, .day], from: date)
        return back.year == y && back.month == m && back.day == d
    }
}

/// 节假日数据：内置 + 本地缓存，每 12 小时联网检查一次新安排
final class HolidayStore: ObservableObject {
    private static let mirrors = [
        "https://cdn.jsdelivr.net/gh/NateScarlet/holiday-cn@master/%d.json",
        "https://raw.githubusercontent.com/NateScarlet/holiday-cn/master/%d.json",
        "https://fastly.jsdelivr.net/gh/NateScarlet/holiday-cn@master/%d.json",
    ]
    private static let refreshInterval: TimeInterval = 12 * 3600

    @Published private(set) var years: [Int: HolidayYear] {
        didSet { table = HolidayTable(years: Array(years.values)) }
    }
    @Published private(set) var table: HolidayTable
    @Published private(set) var isChecking = false
    @Published private(set) var lastError: String?

    private let cacheDirectory: URL?
    private let session: URLSession?
    private var timer: Timer?
    private let calendar = Calendar.autoupdatingCurrent

    /// 今年和明年：明年的安排一般在 11 月前后公布
    var trackedYears: [Int] {
        let year = calendar.component(.year, from: Date())
        return [year, year + 1]
    }

    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("NiumaBuddy/holidays", isDirectory: true)
        cacheDirectory = directory

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 20
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.httpCookieStorage = nil
        session = URLSession(configuration: config)

        var loaded: [Int: HolidayYear] = [:]
        for year in BuiltinHolidays.years {
            loaded[year.year] = year
        }
        let thisYear = Calendar.autoupdatingCurrent.component(.year, from: Date())
        for year in (thisYear - 1)...(thisYear + 1) {
            if let cached = Self.loadCache(year: year, from: directory) {
                Self.merge(cached, into: &loaded)
            }
        }
        years = loaded
        table = HolidayTable(years: Array(loaded.values))

        refresh()
        let timer = Timer(timeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// 截图、自检用：只用给定的数据，不联网、不读写缓存
    init(offline data: [HolidayYear]) {
        cacheDirectory = nil
        session = nil
        years = Dictionary(data.map { ($0.year, $0) }, uniquingKeysWith: { _, last in last })
        table = HolidayTable(years: data)
    }

    deinit {
        timer?.invalidate()
    }

    func refresh() {
        guard let session, !isChecking else { return }
        isChecking = true
        let targets = trackedYears
        var results: [Int: HolidayYear] = [:]
        let group = DispatchGroup()
        for year in targets {
            group.enter()
            Self.fetch(year: year, session: session) { result in
                DispatchQueue.main.async {
                    if let result { results[year] = result }
                    group.leave()
                }
            }
        }
        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            self.isChecking = false
            guard !results.isEmpty else {
                self.lastError = "连不上节假日数据源，先用已有的数据"
                return
            }
            self.lastError = nil
            var updated = self.years
            for (_, year) in results.sorted(by: { $0.key < $1.key }) {
                Self.merge(year, into: &updated)
                self.saveCache(year)
            }
            self.years = updated
        }
    }

    /// 已经有公布的安排时，不拿「未公布」把它盖掉
    private static func merge(_ incoming: HolidayYear, into years: inout [Int: HolidayYear]) {
        if incoming.isPublished || !(years[incoming.year]?.isPublished ?? false) {
            years[incoming.year] = incoming
        }
    }

    /// 依次试几个镜像，第一个拿到合法数据的为准
    private static func fetch(year: Int, session: URLSession, mirror: Int = 0, completion: @escaping (HolidayYear?) -> Void) {
        guard mirror < mirrors.count, let url = URL(string: String(format: mirrors[mirror], year)) else {
            completion(nil)
            return
        }
        session.dataTask(with: url) { data, response, _ in
            if let data, (response as? HTTPURLResponse)?.statusCode == 200,
               var parsed = HolidayParser.parse(data, expectedYear: year) {
                parsed.fetchedAt = Date()
                completion(parsed)
            } else {
                fetch(year: year, session: session, mirror: mirror + 1, completion: completion)
            }
        }.resume()
    }

    private static func cacheURL(year: Int, in directory: URL?) -> URL? {
        directory?.appendingPathComponent("\(year).json", isDirectory: false)
    }

    private static func loadCache(year: Int, from directory: URL?) -> HolidayYear? {
        guard let url = cacheURL(year: year, in: directory),
              let data = try? Data(contentsOf: url), data.count <= HolidayParser.maxBytes,
              let saved = try? JSONDecoder().decode(HolidayYear.self, from: data) else { return nil }
        return HolidayParser.validated(saved, expectedYear: year)
    }

    private func saveCache(_ year: HolidayYear) {
        guard let directory = cacheDirectory, let url = Self.cacheURL(year: year.year, in: directory),
              let data = try? JSONEncoder().encode(year) else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}
