package enum AttestationPayload {
    package static func canonical(method:String,path:String,bodySHA256:String,timestamp:String,challenge:String)->String {
        "\(method.uppercased())\n\(path)\n\(bodySHA256)\n\(timestamp)\n\(challenge)"
    }
}
