//
//  ExchangeRateService.swift
//  japanShopping
//

import Combine
import Foundation

protocol ExchangeRateService {
    func latestRate() -> AnyPublisher<ExchangeRate, Error>
}

enum ExchangeRateServiceError: LocalizedError {
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "匯率服務網址不正確"
        }
    }
}

final class RemoteExchangeRateService: ExchangeRateService {

    private enum Constants {
        /// exchangerate-api.com 的免金鑰端點。
        ///
        /// 刻意不用需要金鑰的 v6 端點：金鑰會被打包進 App，任何人解開 App 都拿得到，
        /// 放在專案設定或遠端設定都只是換個地方藏。真要保護金鑰得由後端代理，
        /// 而這個 App 只需要每天一次的匯率，免金鑰端點就夠。
        static let latestRateURL = "https://open.er-api.com/v6/latest/USD"
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func latestRate() -> AnyPublisher<ExchangeRate, Error> {
        guard let url = URL(string: Constants.latestRateURL) else {
            return Fail(error: ExchangeRateServiceError.invalidURL).eraseToAnyPublisher()
        }

        return session.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: ExchangeRate.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
}
