{
  description = "Eclipse Platform Releng Aggregator development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
        # Use Java 24 (or latest available)
        jdk = pkgs.jdk;

        # Source derivation
        # IMPORTANT: builtins.path and lib.cleanSource do NOT include git submodules!
        # You MUST use fetchFromGitHub with fetchSubmodules=true for this to work.

        # Option 1: Use fetchFromGitHub for full reproducibility (REQUIRED)
        # To get the sha256, run: nix build .#ecj
        # Nix will error with the correct sha256 hash - copy it and replace the placeholder below
        source = pkgs.fetchFromGitHub {
          owner = "maxeler";
          repo = "eclipse.platform.releng.aggregator";
          rev = "e7f40bf9ae1bb249802b16529172ccf3e0dc6357";
          sha256 = "sha256-3w6sp7zpcA7t4CVKaiVGwqBbXfCqGsVJ4FHr38j176o=";
          fetchSubmodules = true;
        };

        # Option 2: Use local source (for development - NOT RECOMMENDED)
        # This will NOT work properly because builtins.path doesn't include submodules
        # Uncomment only if you understand the limitations:
        # source = pkgs.runCommand "eclipse-platform-releng-aggregator-source" {
        #   nativeBuildInputs = [ pkgs.git ];
        # } ''
        #   REPO_PATH="${toString ./.}"
        #   cp -rL "$REPO_PATH" $out
        #   chmod -R +w $out
        #   rm -rf $out/.git $out/.m2
        #   find $out -type d -name target -exec rm -rf {} + 2>/dev/null || true
        # '';

        # ECJ build derivation
        ecj = pkgs.stdenv.mkDerivation {
          pname = "eclipse-ecj";
          version = "3.42.0-SNAPSHOT";

          src = source;

          nativeBuildInputs = with pkgs; [
            jdk
            maven
            git
            which
          ];

          # Set up environment variables
          preBuild = ''
            export JAVA_HOME=${jdk}
            export PATH="$JAVA_HOME/bin:$PATH"
            export MAVEN_OPTS="-Xmx2G"
            export WORKSPACE=$PWD
            export M2_REPO=$WORKSPACE/.m2/repository

            # Initialize git repository for Tycho build qualifier
            # Tycho requires git to determine version qualifiers
            echo "Initializing git repository for Tycho..."
            git init
            git config user.email "build@nix"
            git config user.name "Nix Build"
            git add .
            git commit -m "Initial commit for Nix build" || true

            # Initialize git repos in submodules for Tycho
            # Tycho may check submodule directories for git info
            if [ -f .gitmodules ]; then
              echo "Initializing git repositories in submodules..."
              for subdir in eclipse.jdt eclipse.jdt.core eclipse.jdt.core.binaries \
                           eclipse.jdt.debug eclipse.jdt.ui eclipse.jdt.ls \
                           eclipse.pde eclipse.platform eclipse.platform.ui \
                           eclipse.platform.swt equinox equinox.p2 equinox.binaries; do
                if [ -d "$subdir" ] && [ ! -d "$subdir/.git" ]; then
                  echo "Initializing git in $subdir..."
                  (cd "$subdir" && git init && git config user.email "build@nix" && \
                   git config user.name "Nix Build" && git add . && \
                   git commit -m "Initial commit" || true)
                fi
              done
            fi
          '';

          buildPhase = ''
            runHook preBuild

            echo "Building ECJ..."
            mvn clean install \
              -pl :eclipse-sdk-prereqs,:org.eclipse.jdt.core.compiler.batch \
              -DlocalEcjVersion=99.99 \
              -Dmaven.repo.local=$M2_REPO \
              -U \
              -DskipTests=true
          '';

          installPhase = ''
            runHook preInstall

            # Find the ECJ jar file
            ECJ_JAR=$(find eclipse.jdt.core/org.eclipse.jdt.core.compiler.batch/target \
              -name "org.eclipse.jdt.core.compiler.batch-*-SNAPSHOT.jar" | head -1)

            if [ -z "$ECJ_JAR" ]; then
              echo "Error: ECJ jar not found!"
              exit 1
            fi

            echo "Found ECJ jar: $ECJ_JAR"

            # Install the jar
            mkdir -p $out/lib
            cp $ECJ_JAR $out/lib/ecj.jar

            # Also install to a versioned path for reference
            mkdir -p $out/share/eclipse-ecj
            cp $ECJ_JAR $out/share/eclipse-ecj/

            # Create a symlink for convenience
            ln -s $out/lib/ecj.jar $out/ecj.jar

            runHook postInstall
          '';

          # Don't fail if submodules aren't initialized (for local builds)
          dontFixup = true;
        };

        # Eclipse build derivation
        eclipse = pkgs.stdenv.mkDerivation {
          pname = "eclipse-platform";
          version = "4.36.0-SNAPSHOT";

          src = source;

          # Depend on ECJ build - this ensures ECJ is built first
          # and makes the ECJ path available in the build
          buildInputs = [ ecj ];

          nativeBuildInputs = with pkgs; [
            jdk
            maven
            git
            which
          ];

          preBuild = ''
            export JAVA_HOME=${jdk}
            export PATH="$JAVA_HOME/bin:$PATH"
            export MAVEN_OPTS="-Xmx2G"
            export WORKSPACE=$PWD
            export M2_REPO=$WORKSPACE/.m2/repository

            # Initialize git repository for Tycho build qualifier
            # Tycho requires git to determine version qualifiers
            echo "Initializing git repository for Tycho..."
            git init
            git config user.email "build@nix"
            git config user.name "Nix Build"
            git add .
            git commit -m "Initial commit for Nix build" || true

            # Initialize git repos in submodules for Tycho
            if [ -f .gitmodules ]; then
              echo "Initializing git repositories in submodules..."
              for subdir in eclipse.jdt eclipse.jdt.core eclipse.jdt.core.binaries \
                           eclipse.jdt.debug eclipse.jdt.ui eclipse.jdt.ls \
                           eclipse.pde eclipse.platform eclipse.platform.ui \
                           eclipse.platform.swt equinox equinox.p2 equinox.binaries; do
                if [ -d "$subdir" ] && [ ! -d "$subdir/.git" ]; then
                  echo "Initializing git in $subdir..."
                  (cd "$subdir" && git init && git config user.email "build@nix" && \
                   git config user.name "Nix Build" && git add . && \
                   git commit -m "Initial commit" || true)
                fi
              done
            fi

            # Install ECJ with the correct Maven coordinates for Tycho
            # Tycho compiler plugin needs org.eclipse.jdt:ecj:99.99
            ECJ_PATH="${ecj}/lib/ecj.jar"
            if [ -f "$ECJ_PATH" ]; then
              echo "Installing ECJ to Maven repository with coordinates org.eclipse.jdt:ecj:99.99"
              # Install as org.eclipse.jdt:ecj:99.99 (required by Tycho compiler plugin)
              mkdir -p $M2_REPO/org/eclipse/jdt/ecj/99.99
              cp "$ECJ_PATH" $M2_REPO/org/eclipse/jdt/ecj/99.99/ecj-99.99.jar
              
              # Also create the POM file for this artifact
              cat > $M2_REPO/org/eclipse/jdt/ecj/99.99/ecj-99.99.pom <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <groupId>org.eclipse.jdt</groupId>
  <artifactId>ecj</artifactId>
  <version>99.99</version>
  <packaging>jar</packaging>
</project>
EOF
              
              # Also install with the original coordinates for compatibility
              mkdir -p $M2_REPO/org/eclipse/jdt/org.eclipse.jdt.core.compiler.batch/3.42.0-SNAPSHOT
              cp "$ECJ_PATH" $M2_REPO/org/eclipse/jdt/org.eclipse.jdt.core.compiler.batch/3.42.0-SNAPSHOT/org.eclipse.jdt.core.compiler.batch-3.42.0-SNAPSHOT.jar
            else
              echo "Error: ECJ not found at $ECJ_PATH"
              echo "Building ECJ first..."
              mvn clean install \
                -pl :eclipse-sdk-prereqs,:org.eclipse.jdt.core.compiler.batch \
                -DlocalEcjVersion=99.99 \
                -Dmaven.repo.local=$M2_REPO \
                -U \
                -DskipTests=true
            fi
          '';

          buildPhase = ''
            runHook preBuild

            echo "Building Eclipse Platform..."
            mvn clean verify \
              -e \
              -Dmaven.repo.local=$M2_REPO \
              -T 1C \
              -DskipTests=true \
              -Dcompare-version-with-baselines.skip=true \
              -DapiBaselineTargetDirectory=$WORKSPACE \
              -Dcbi-ecj-version=99.99 \
              -Dtycho.disableP2Mirrors=true \
              -U
          '';

          installPhase = ''
            runHook preInstall

            # Find the distribution builds
            DIST_DIR=eclipse.platform.releng.tychoeclipsebuilder/eclipse.platform.repository/target/products

            if [ ! -d "$DIST_DIR" ]; then
              echo "Error: Distribution directory not found: $DIST_DIR"
              exit 1
            fi

            echo "Installing Eclipse distributions..."
            mkdir -p $out/distributions
            cp -r $DIST_DIR/* $out/distributions/

            # Create symlinks for the most relevant distributions
            if [ -f "$out/distributions/org.eclipse.sdk.ide-macosx.cocoa.aarch64.tar.gz" ]; then
              ln -s $out/distributions/org.eclipse.sdk.ide-macosx.cocoa.aarch64.tar.gz \
                $out/eclipse-sdk-macos-aarch64.tar.gz
            fi

            if [ -f "$out/distributions/org.eclipse.sdk.ide-linux.gtk.x86_64.tar.gz" ]; then
              ln -s $out/distributions/org.eclipse.sdk.ide-linux.gtk.x86_64.tar.gz \
                $out/eclipse-sdk-linux-x86_64.tar.gz
            fi

            runHook postInstall
          '';

          # Don't fail if submodules aren't initialized (for local builds)
          dontFixup = true;
        };

      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            jdk
            maven
            git
          ];

          shellHook = ''
            export JAVA_HOME=${jdk}
            export PATH="$JAVA_HOME/bin:$PATH"
            echo "Java version:"
            java -version
            echo ""
            echo "Maven version:"
            mvn -version
          '';
        };

        packages = {
          ecj = ecj;
          eclipse = eclipse;
          default = eclipse;
        };
      }
    );
}
