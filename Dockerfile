# ========== ① ビルドステージ（作業場） ==========
# ベースイメージはECRプルスルーキャッシュ経由で取得（上流=ECR Public）
FROM 882567865866.dkr.ecr.ap-northeast-1.amazonaws.com/ecr-public/amazoncorretto/amazoncorretto:25 AS builder

# Mavenをインストール（Corretto25イメージにはMavenが入っていないため）
# 配布元は全バージョンを恒久保存するApache Archiveを使用（ミラーのURL消失による404を回避）
ARG MAVEN_VERSION=3.9.16
RUN yum install -y tar gzip && \
    curl -fsSL https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz -o /tmp/maven.tar.gz && \
    tar -xzf /tmp/maven.tar.gz -C /opt && \
    rm /tmp/maven.tar.gz
ENV PATH="/opt/apache-maven-${MAVEN_VERSION}/bin:${PATH}"

# CodeArtifactの認証トークンを受け取る（ビルド時に外から渡す）
ARG CODEARTIFACT_AUTH_TOKEN
ENV CODEARTIFACT_AUTH_TOKEN=${CODEARTIFACT_AUTH_TOKEN}

WORKDIR /app

# 設定ファイルとソースをコピー
COPY settings.xml .
COPY pom.xml .
COPY src ./src

# Mavenでビルド（ここでCodeArtifactからOtelを取得）
RUN mvn -s settings.xml clean package

# ========== ② 実行ステージ（完成品） ==========
# ベースイメージはECRプルスルーキャッシュ経由で取得（上流=ECR Public）
FROM 882567865866.dkr.ecr.ap-northeast-1.amazonaws.com/ecr-public/amazoncorretto/amazoncorretto:25 AS runtime

WORKDIR /app

# ビルドステージで作ったJARだけをコピー（トークンやMavenは残さない）
COPY --from=builder /app/target/java-otel-app.jar app.jar

# コンテナ起動時にJARを実行
ENTRYPOINT ["java", "-jar", "app.jar"]
