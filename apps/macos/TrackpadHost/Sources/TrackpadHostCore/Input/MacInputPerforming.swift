public protocol MacInputPerforming {
    func perform(_ command: MacInputCommand)
}

extension MacInputInjector: MacInputPerforming {}
