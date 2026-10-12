#pragma once
#include <QAudioSink>
#include <QBuffer>
#include <QElapsedTimer>
#include <QFutureWatcher>
#include <QObject>
#include <QStringList>
#include <QTimer>
#include <cstdint>
#include <memory>

class ShowDirector : public QObject {
    Q_OBJECT
    Q_PROPERTY(double time READ time NOTIFY timeChanged)
    Q_PROPERTY(bool running READ running NOTIFY runningChanged)
    Q_PROPERTY(int seed READ seed WRITE setSeed NOTIFY seedChanged)
    Q_PROPERTY(int shellType READ shellType WRITE setShellType NOTIFY shellTypeChanged)
    Q_PROPERTY(QStringList shellNames READ shellNames CONSTANT)
    // Parallel to shellNames. The settings card describes the shell the
    // user has selected, which is not always the one the director last
    // played — a named-shell payload plays one without changing it.
    Q_PROPERTY(QStringList shellDescriptions READ shellDescriptions CONSTANT)
    Q_PROPERTY(QString shellName READ shellName NOTIFY shellTypeChanged)
    Q_PROPERTY(QString shellDescription READ shellDescription NOTIFY shellTypeChanged)
    Q_PROPERTY(double previewTime READ previewTime NOTIFY shellTypeChanged)
    Q_PROPERTY(bool audioEnabled READ audioEnabled WRITE setAudioEnabled NOTIFY audioEnabledChanged)
    Q_PROPERTY(float volume READ volume WRITE setVolume NOTIFY volumeChanged)
    // Where the shell goes up, as a fraction of the launch spread: -1 is as far
    // left as a burst can sit and still fit, +1 as far right, 0 the middle.
    Q_PROPERTY(float launchX READ launchX WRITE setLaunchX NOTIFY originXChanged)
    // Pick a fresh spot for every launch instead of using launchX. Derived from
    // the seed and a launch counter, so a given seed still replays identically.
    Q_PROPERTY(bool randomLaunch READ randomLaunch WRITE setRandomLaunch NOTIFY originXChanged)
    // The resolved world position the current show launches from. Read-only:
    // views bind to this, not to launchX, so random placement reaches them.
    Q_PROPERTY(float originX READ originX NOTIFY originXChanged)
    Q_PROPERTY(double duration READ duration CONSTANT)
  public:
    explicit ShowDirector(QObject *parent = nullptr);
    ~ShowDirector() override;
    double time() const { return m_time; }
    bool running() const { return m_running; }
    int seed() const { return m_seed; }
    int shellType() const { return m_shellType; }
    QStringList shellNames() const;
    QStringList shellDescriptions() const;
    QString shellName() const;
    QString shellDescription() const;
    double previewTime() const;
    Q_INVOKABLE int shellIndex(const QString &slug) const;
    bool audioEnabled() const { return m_audioEnabled; }
    float volume() const { return m_volume; }
    float launchX() const { return m_launchX; }
    bool randomLaunch() const { return m_randomLaunch; }
    float originX() const { return m_originX; }
    double duration() const;
    void setSeed(int seed);
    void setShellType(int type);
    void setAudioEnabled(bool enabled);
    void setVolume(float volume);
    void setLaunchX(float value);
    void setRandomLaunch(bool value);
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
    void originXChanged();
    void finished();

  private:
    void prepareAudio();
    void startAudio();
    void stopAudio();
    void resolveOrigin();
    double m_time = 0, m_base = 0;
    bool m_running = false, m_audioEnabled = true;
    int m_seed = 73, m_preparingSeed = 0, m_readySeed = -1;
    int m_shellType = 0, m_preparingShell = 0, m_readyShell = -1;
    float m_volume = 0.35f;
    float m_launchX = 0, m_originX = 0;
    // The audio image leans towards the launch, so a show prepared for one
    // position cannot be replayed at another. Cached alongside seed and shell.
    float m_preparingBias = 0, m_readyBias = 0;
    bool m_randomLaunch = false;
    // Advanced once per launch so random placement moves; folded with the seed
    // so a given seed replays the same sequence of positions.
    std::uint32_t m_launchCount = 0;
    QElapsedTimer m_clock;
    QTimer m_timer;
    QFutureWatcher<QByteArray> m_preparation;
    QByteArray m_pcm;
    QBuffer m_buffer;
    std::unique_ptr<QAudioSink> m_sink;
};
