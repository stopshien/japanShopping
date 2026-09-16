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
    case missingAPIKey
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "找不到匯率 API 金鑰設定"
        case .invalidURL:
            return "匯率服務網址不正確"
        }
    }
}

final class RemoteExchangeRateService: ExchangeRateService {

    private enum Constants {
        static let apiKeyInfoPlistKey = "ExchangeRateAPIKey"
        static let baseURL = "https://v6.exchangerate-api.com/v6"
    }

    private let session: URLSession
    private let apiKey: String?

    init(session: URLSession = .shared, bundle: Bundle = .main) {
        self.session = session
        self.apiKey = bundle.object(forInfoDictionaryKey: Constants.apiKeyInfoPlistKey) as? String
    }

    func latestRate() -> AnyPublisher<ExchangeRate, Error> {
        guard let apiKey, !apiKey.isEmpty else {
            return Fail(error: ExchangeRateServiceError.missingAPIKey).eraseToAnyPublisher()
        }
        guard let url = URL(string: "\(Constants.baseURL)/\(apiKey)/latest/USD") else {
            return Fail(error: ExchangeRateServiceError.invalidURL).eraseToAnyPublisher()
        }

        return session.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: ExchangeRate.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
}
