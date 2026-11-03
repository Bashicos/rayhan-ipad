import Foundation

/// Bill for one patient, worked out the same way as the demo (prices, add-ons, gifts, discounts, hand-set total, payments oldest first).
struct BillRow: Identifiable {
    let proc: Procedure
    var id: String { proc.id }
    let name: String
    let units: Int
    let list: Double
    let base: Double
    let gift: Bool
    let adds: [(id: String, name: String, list: Double, price: Double, gift: Bool)]
    let gross: Double
    let pdisc: Double
    let rowDisc: Double
    let sub: Double
    let giftValue: Double
    let labCost: Double
    let labName: String
    let overridden: Bool
    let day: Date
    var net: Double = 0
    var paid: Double = 0
    var left: Double = 0
    var state: PayState = .unpaid
}

enum PayState: String { case paid, part, unpaid, gift, free
    var label: String { switch self { case .paid: "Paid"; case .part: "Part paid"; case .unpaid: "Not paid"; case .gift: "Gift"; case .free: "Free" } }
}

struct Bill {
    var rows: [BillRow]
    var charged: [BillRow]
    var planned: [BillRow]
    var subT: Double
    var planT: Double
    var rowDiscT: Double
    var labT: Double
    var discRaw: Double
    var agreed: Double?
    var total: Double
    var pays: [Payment]
    var paid: Double
    var due: Double { total - paid }
    var credit: Double
    var gifts: Double
    var disc: Double { subT - total }
}

enum BillEngine {
    static func bill(_ p: Patient, labs: [Lab], fx: FX, base: Currency = .usd) -> Bill {
        let B = p.billing
        var rows: [BillRow] = p.procs.map { r in
            let tp = Catalog.type(r.type)
            let units = max(1, r.teeth.count), per = r.type == "bridge"
            let list = (tp?.price ?? 0) * Double(per ? units : 1)
            let baseP = r.price ?? list
            let adds = r.addons.map { a -> (id: String, name: String, list: Double, price: Double, gift: Bool) in
                let ad = Catalog.addon(a); let lp = ad?.price ?? 0
                return (a, ad?.name ?? a, lp, r.addPrices[a] ?? lp, r.giftAddons.contains(a))
            }
            let gross = (r.gift ? 0 : baseP) + adds.reduce(0) { $0 + ($1.gift ? 0 : $1.price) }
            let pd = max(0, min(100, r.discPct)), rowDisc = gross * pd / 100
            let giftV = (r.gift ? baseP : 0) + adds.reduce(0) { $0 + ($1.gift ? $1.price : 0) }
            var labCost = 0.0, labName = ""
            if let L = r.lab, let lb = labs.first(where: { $0.id == L.lab }) {
                labName = lb.name
                if let sv = lb.services.first(where: { $0.id == L.svc }) {
                    labCost = fx.conv(sv.price * Double(sv.name.lowercased().contains("per unit") ? units : 1), lb.cur, base)
                }
            }
            return BillRow(proc: r, name: tp?.name ?? r.type, units: units, list: list, base: baseP, gift: r.gift, adds: adds, gross: gross, pdisc: pd, rowDisc: rowDisc, sub: gross - rowDisc, giftValue: giftV, labCost: labCost, labName: labName, overridden: r.price != nil && r.price != list, day: r.doneAt ?? r.at)
        }
        var charged = rows.filter { $0.proc.status != .plan }.sorted { $0.day < $1.day }
        let planned = rows.filter { $0.proc.status == .plan }
        let subT = charged.reduce(0) { $0 + $1.sub }, planT = planned.reduce(0) { $0 + $1.sub }
        let discRaw = min(subT, B.discKind == .pct ? subT * B.discValue / 100 : B.discValue)
        let total = B.agreed.map { max(0, $0) } ?? (subT - discRaw)
        let factor = subT > 0 ? total / subT : 0
        for i in charged.indices { charged[i].net = charged[i].sub * factor; charged[i].left = charged[i].net }
        let pays = B.pays.sorted { $0.at < $1.at }
        var credit = 0.0
        for py in pays {
            var v = fx.conv(py.amount, py.cur, base, rateFrom: py.rate)
            func take(_ i: Int) { let t = min(v, charged[i].left); charged[i].left -= t; charged[i].paid += t; v -= t }
            for id in py.items { if let i = charged.firstIndex(where: { $0.id == id }), v > 0 { take(i) } }
            for i in charged.indices where v > 0 { take(i) }
            credit += v
        }
        for i in charged.indices {
            let x = charged[i]
            charged[i].state = x.net <= 0.004 ? (x.gift || x.giftValue > 0 ? .gift : .free) : x.left <= 0.004 ? .paid : x.paid > 0.004 ? .part : .unpaid
        }
        let paid = pays.reduce(0) { $0 + fx.conv($1.amount, $1.cur, base, rateFrom: $1.rate) }
        // keep row states on the full list too
        for i in rows.indices { if let c = charged.first(where: { $0.id == rows[i].id }) { rows[i] = c } }
        return Bill(rows: rows, charged: charged, planned: planned, subT: subT, planT: planT, rowDiscT: charged.reduce(0) { $0 + $1.rowDisc }, labT: charged.reduce(0) { $0 + $1.labCost }, discRaw: discRaw, agreed: B.agreed, total: total, pays: pays, paid: paid, credit: credit, gifts: rows.reduce(0) { $0 + $1.giftValue })
    }
}
