#pragma once
#include <QAudioSink>
#include <QBuffer>
#include <QElapsedTimer>
#include <QFutureWatcher>
#include <QObject>
#include <QStringList>
#include <QTimer>
#include <memory>

class ShowDirector : public QObject {
    Q_OBJECT
    Q_PROPERTY(double time READ time NOTIFY timeChanged)
    Q_PROPERTY(bool running READ running NOTIFY runningChanged)
    Q_PROPERTY(int seed READ seed WRITE setSeed NOTIFY seedChanged)
    Q_PROPERTY(int shellType READ shellType WRITE setShellType NOTIFY shellTypeChanged)
    Q_PROPERTY(QStringList shellNames READ shellNames CONSTANT)
    Q_PROPERTY(QString shellName READ shellName NOTIFY shellTypeChanged)
    Q_PROPERTY(QString shellDescription READ shellDescription NOTIFY shellTypeChanged)
    Q_PROPERTY(double previewTime READ previewTime NOTIFY shellTypeChanged)
    Q_PROPERTY(bool audioEnabled READ audioEnabled WRITE setAudioEnabled NOTIFY audioEnabledChanged)
    Q_PROPERTY(float volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(double duration READ duration CONSTANT)
  public:
    explicit ShowDirector(QObject *parent = nullptr);
    ~ShowDirector() override;
    double time() const { return m_time; }
    bool running() const { return m_running; }
    int seed() const { return m_seed; }
    int shellType() const { return m_shellType; }
    QStringList shellNames() const;
    QString shellName() const;
    QString shellDescription() const;
    double previewTime() const;
    Q_INVOKABLE int shellIndex(const QString &slug) const;
    bool audioEnabled() const { return m_audioEnabled; }
    float volume() const { return m_volume; }
    double duration() const;
    void setSeed(int seed);
    void setShellType(int type);
    void setAudioEnabled(bool enabled);
    void setVolume(float volume);
    Q_INVOKABLE void launch();
    Q_INVOKABLE void pause();
    Q_INVOKABLE void resume();
    Q_INVOKABLE void seek(double time);
  signals:
    void timeChanged();
    void runningChanged();
    void seedChanged();
    void shellTypeChanged();
    void audioEnabledChanged();
    void volumeChanged();
    void finished();

  private:
    void prepareAudio();
    void startAudio();
    void stopAudio();
    double m_time = 0, m_base = 0;
    bool m_running = false, m_audioEnabled = true;
    int m_seed = 73, m_preparingSeed = 0, m_readySeed = -1;
    int m_shellType = 0, m_preparingShell = 0, m_readyShell = -1;
    float m_volume = 0.35f;
    QElapsedTimer m_clock;
    QTimer m_timer;
    QFutureWatcher<QByteArray> m_preparation;
    QByteArray m_pcm;
    QBuffer m_buffer;
    std::unique_ptr<QAudioSink> m_sink;
};
