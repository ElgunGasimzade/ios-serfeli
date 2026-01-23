import SwiftUI
import Combine

class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    @Published var language: String {
        didSet {
            UserDefaults.standard.set(language, forKey: "selectedLanguage")
        }
    }
    
    init() {
        self.language = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "en"
    }
    
    func localized(_ key: String) -> String {
        let dict = translations[language] ?? translations["en"]!
        return dict[key] ?? key
    }
    
    private let translations: [String: [String: String]] = [
        "en": [
            "Home": "Home",
            "Scan": "Scan",
            "Watchlist": "Watchlist",
            "Profile": "Profile",
            "Daily Deals": "Daily Deals",
            "Search products...": "Search products...",
            "Loading...": "Loading...",
            "Guest User": "Guest User",
            "Language": "Language",
            "Select Language": "Select Language",
            "Ends soon": "Ends soon",
            "No routes calculated.": "No routes calculated.",
            "Back to Home": "Back to Home",
            "TOTAL SAVINGS": "TOTAL SAVINGS",
            "Lifetime Earnings": "Lifetime Earnings",
            "All Time": "All Time",
            "saved total": "saved total",
            "Deals Scouted": "Deals Scouted",
            "Your \"Wage\"": "Your \"Wage\"",
            "Value earned vs time spent shopping.": "Value earned vs time spent shopping.",
            "Prices checked by us so you don't have to.": "Prices checked by us so you don't have to.",
            "You spent": "You spent",
            "shopping.": "shopping.",
            "Save": "Save",
            "total": "total",
            "Select Route": "Select Route",
            "MAX SAVINGS": "MAX SAVINGS",
            "OPTION A": "OPTION A",
            "OPTION B": "OPTION B",
            "We found ways": "We found ways",
            "to complete your list.": "to complete your list.",
            "Choose the option that fits your schedule.": "Choose the option that fits your schedule.",
            "Review Items": "Review Items",
             "Are these items correct?": "Are these items correct?",
             "Tap to edit or remove items from your list.": "Tap to edit or remove items from your list.",
             "Find Best Route": "Find Best Route",
             "Add Item to Watchlist": "Add Item to Watchlist",
            "Active": "Active",
            "Please review the deals we found. You can choose a specific brand or stick with your generic request.": "Please review the deals we found. You can choose a specific brand or stick with your generic request.",
            "No deals found": "No deals found",
            "Best Value Found": "Best Value Found",
            "Add to List": "Add to List",
            "No discounts found nearby": "No discounts found nearby",
            "Continue to Route": "Continue to Route",
            "No Deals": "No Deals",
            "Compare Brands": "Compare Brands",
            "Best Value": "Best Value",
            "Alternative": "Alternative",
            "Select Brand": "Select Brand",
            "Selected": "Selected",
            "Active Trip": "Active Trip",
            "Stops": "Stops",
            "Savings": "Savings",
            "Complete Shopping Trip": "Complete Shopping Trip",
            "Navigate": "Navigate",
            "Items": "Items",
            "away": "away",
            "Jan": "Jan", "Feb": "Feb", "Mar": "Mar", "Apr": "Apr", "May": "May", "Jun": "Jun", "Jul": "Jul", "Aug": "Aug"
        ],
        "az": [
            "Home": "Ana Səhifə",
            "Scan": "Skan",
            "Watchlist": "İzləmə",
            "Profile": "Profil",
            "Daily Deals": "Günün Təklifləri",
            "Search products...": "Məhsul axtar...",
            "Loading...": "Yüklənir...",
            "Guest User": "İstifadəçi",
            "Language": "Dil",
            "Select Language": "Dili Seçin",
            "Ends soon": "Bitmək üzrə",
            "No routes calculated.": "Marşrut tapılmadı.",
            "Back to Home": "Ana Səhifəyə Qayıt",
            "TOTAL SAVINGS": "ÜMUMİ QƏNAƏT",
            "Lifetime Earnings": "Ümumi Qazanc",
            "All Time": "Bütün dövr",
            "saved total": "ümumi qənaət",
            "Deals Scouted": "Təkliflər Yoxlanıldı",
            "Your \"Wage\"": "Sizin \"Maaş\"",
            "Value earned vs time spent shopping.": "Alış-verişə sərf olunan vaxta qarşı qazanc.",
            "Prices checked by us so you don't have to.": "Qiymətləri sizin yerinizə biz yoxladıq.",
            "You spent": "Siz xərclədiniz",
            "shopping.": "alış-verişdə.",
            "Save": "Qənaət",
            "total": "cəmi",
            "Select Route": "Marşrutu Seç",
            "MAX SAVINGS": "MAKSİMUM QƏNAƏT",
            "OPTION A": "SEÇİM A",
            "OPTION B": "SEÇİM B",
            "We found ways": "Yol tapdıq",
            "to complete your list.": "siyahınızı tamamlamaq üçün.",
            "Choose the option that fits your schedule.": "Cədvəlinizə uyğun seçimi edin.",
            "Review Items": "Məhsulları Yoxla",
            "Are these items correct?": "Bu məhsullar düzgündür?",
            "Tap to edit or remove items from your list.": "Siyahıdan silmək və ya düzəltmək üçün toxunun.",
            "Find Best Route": "Ən Yaxşı Yolu Tap",
            "Add Item to Watchlist": "Siyahıya əlavə et",
            "Tracking": "İzlənilir",
            "Recent Scans": "Son Skanlar",
            "Popular Essentials": "Populyar Məhsullar",
            "Active": "Aktiv",
            "Please review the deals we found. You can choose a specific brand or stick with your generic request.": "Tapdığımız təklifləri yoxlayın. Xüsusi marka seçə və ya ümumi sorğunuzda qala bilərsiniz.",
            "No deals found": "Təklif tapılmadı",
            "Best Value Found": "Ən Sərfəli",
            "Add to List": "Siyahıya əlavə et",
            "No discounts found nearby": "Yaxınlıqda endirim tapılmadı",
            "Continue to Route": "Marşruta Davam Et",
            "No Deals": "Təklif Yoxdur",
            "Compare Brands": "Brendləri Müqayisə Et",
            "Best Value": "Ən Sərfəli",
            "Alternative": "Alternativ",
            "Select Brand": "Brend Seç",
            "Selected": "Seçildi",
            "Active Trip": "Aktiv Səfər",
            "Stops": "Dayanacaq",
            "Savings": "Qənaət",
            "Complete Shopping Trip": "Alış-verişi Tamamla",
            "Navigate": "Naviqasiya",
            "Items": "Məhsul",
            "away": "məsafədə",
            "Jan": "Yan", "Feb": "Fev", "Mar": "Mar", "Apr": "Apr", "May": "May", "Jun": "İyun", "Jul": "İyul", "Aug": "Avq"
        ]
    ]
}

extension String {
    var localized: String {
        return LocalizationManager.shared.localized(self)
    }
}
