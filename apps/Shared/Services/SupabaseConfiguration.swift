import Foundation
import Supabase

struct SupabaseConfiguration: Sendable {
    let url: URL
    let publishableKey: String

    static var production: SupabaseConfiguration {
        let environment = ProcessInfo.processInfo.environment
        let urlString = environment["MASTER_DANCE_SUPABASE_URL"]
            ?? "https://szienrktsikxwdnrrudo.supabase.co"
        let publishableKey = environment["MASTER_DANCE_SUPABASE_PUBLISHABLE_KEY"]
            ?? "sb_publishable_oOg7RYMXv83Ofwf2NjgrlA_EcCKFMab"

        guard let url = URL(string: urlString) else {
            preconditionFailure("MASTER_DANCE_SUPABASE_URL is invalid")
        }
        return SupabaseConfiguration(url: url, publishableKey: publishableKey)
    }

    func makeClient() -> SupabaseClient {
        SupabaseClient(supabaseURL: url, supabaseKey: publishableKey)
    }
}
