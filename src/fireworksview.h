#pragma once
#include <QQuickRhiItem>

class FireworksView : public QQuickRhiItem {
    Q_OBJECT
    Q_PROPERTY(double time READ time WRITE setTime NOTIFY timeChanged)
    Q_PROPERTY(int seed READ seed WRITE setSeed NOTIFY seedChanged)
    Q_PROPERTY(int shellType READ shellType WRITE setShellType NOTIFY shellTypeChanged)
    Q_PROPERTY(float exposure READ exposure WRITE setExposure NOTIFY exposureChanged)
    Q_PROPERTY(float bloom READ bloom WRITE setBloom NOTIFY bloomChanged)
    Q_PROPERTY(float wind READ wind WRITE setWind NOTIFY windChanged)
  public:
    explicit FireworksView(QQuickItem *parent = nullptr);
    double time() const { return m_time; }
    int seed() const { return m_seed; }
    int shellType() const { return m_shellType; }
    float exposure() const { return m_exposure; }
    float bloom() const { return m_bloom; }
    float wind() const { return m_wind; }
    void setTime(double value);
    void setSeed(int value);
    void setShellType(int value);
    void setExposure(float value);
    void setBloom(float value);
    void setWind(float value);
  signals:
    void timeChanged();
    void seedChanged();
    void shellTypeChanged();
    void exposureChanged();
    void bloomChanged();
    void windChanged();

  protected:
    QQuickRhiItemRenderer *createRenderer() override;

  private:
    double m_time = 0;
    int m_seed = 73;
    int m_shellType = 0;
    float m_exposure = 0.95f, m_bloom = 0.85f, m_wind = 2.2f;
};
