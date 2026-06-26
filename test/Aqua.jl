using Aqua

@testset "Aqua" begin
    Aqua.test_all(
        JessamineSciKitLearn;
        stale_deps=(ignore=[:Revise],),
        deps_compat=(ignore=[:Jessamine, :JessamineSymbolics, :JessamineCLI],),
        piracies=false,
    )
end
