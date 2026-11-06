# Тестирование на доступность (Woof)

Доступность (accessibility) — это удобство приложения для людей с ослабленным зрением, слухом, ограниченной ловкостью рук и другими особенностями. В этой работе вы научитесь описывать элементы интерфейса так, чтобы их понимали программы чтения с экрана, и проверите приложение **Woof** — список собак.

### Пререквизиты

- Приложение **Woof** из лекции 18 «Material Design (Woof)».
- Умение выводить списки через `FlatList` и обрабатывать нажатия через `Pressable`.
- Практическая работа 15 «Создание автоматизированных тестов»: Jest и `@testing-library/react-native`.

### Что вы узнаете

- Как описывать элементы свойствами `accessibilityLabel`, `accessibilityRole`, `accessibilityHint` и `accessibilityState`.
- Почему важны крупные цели нажатия и достаточный контраст.
- Как вручную проверить приложение с VoiceOver и TalkBack.
- Как автоматически проверить доступность тестами с `getByLabelText` и `getByRole`.

### Что вы создадите

Приложение **Woof** с доступными карточками собак и файл `__tests__/App.test.tsx`, который проверяет метки, роли и раскрытие карточек.

## Зачем нужна доступность

Не все пользователи видят экран одинаково: кто-то пользуется программой чтения с экрана, кто-то увеличивает шрифт, кто-то управляет телефоном переключателями вместо касаний. Если элементы интерфейса не описаны, такие пользователи не смогут понять содержимое или выполнить действие.

## Атрибуты доступности в React Native

- `accessible` — объединяет содержимое контейнера в один элемент, который программа чтения с экрана произносит целиком.
- `accessibilityLabel` — текст, который услышит пользователь; заменяет чтение содержимого элемента.
- `accessibilityRole` — роль элемента: `'button'`, `'header'`, `'image'`, `'text'`.
- `accessibilityHint` — подсказка о результате действия: «Показывает или скрывает хобби собаки».
- `accessibilityState` — состояние элемента: `{ expanded: true }`, `{ disabled: true }`, `{ selected: true }`.

```tsx
<Pressable
  onPress={toggle}
  accessible
  accessibilityRole="button"
  accessibilityLabel={`${dog.name}, возраст ${dog.age}`}
  accessibilityHint="Показывает или скрывает хобби собаки"
  accessibilityState={{ expanded }}
>
```

Значимым изображениям (`Image`) задают `accessibilityLabel`, а чисто декоративные элементы не должны попадать в фокус — им не указывают роль и метку.

## Крупные цели нажатия и контраст

- Любой элемент, по которому нажимают, должен быть не меньше **44 × 44** пикселей.
- Если кнопка визуально маленькая, зону нажатия расширяют свойством `hitSlop`.
- Контраст текста к фону — не ниже **4,5 : 1** для мелкого текста и **3 : 1** для крупного; пару цветов удобно проверять онлайн-проверщиком контраста.

```tsx
<Pressable hitSlop={8} style={styles.toggle}>
  <Text style={styles.chevron}>{expanded ? '▴' : '▾'}</Text>
</Pressable>
```

## Шаг 1. Создание проекта

Создайте проект или откройте Woof из лекции 18:

```bash
npx create-expo-app@latest woof-access --template blank-typescript
cd woof-access
npx expo start
```

Все изменения этой работы вносятся в файл `App.tsx`; полный код — на шаге 2.

## Шаг 2. Полный код App.tsx

Чтобы программа чтения с экрана воспринимала карточку как одну кнопку, метку, роль, подсказку и состояние задают прямо на `Pressable`; стрелка остаётся декоративной.

```tsx
import { StatusBar } from 'expo-status-bar'
import { useState } from 'react'
import { FlatList, Pressable, StyleSheet, Text, View } from 'react-native'

type Dog = { id: string; name: string; age: number; hobby: string }

const dogs: Dog[] = [
  { id: '1', name: 'Рекс', age: 3, hobby: 'Любит приносить мяч и плавать в озере.' },
  { id: '2', name: 'Лесси', age: 5, hobby: 'Обожает долгие прогулки в парке.' },
  { id: '3', name: 'Барон', age: 2, hobby: 'Гоняет мяч по двору и учит новые команды.' },
]

function DogCard({ dog }: { dog: Dog }) {
  const [expanded, setExpanded] = useState(false)

  return (
    <View style={styles.card}>
      <Pressable
        onPress={() => setExpanded(!expanded)}
        style={styles.header}
        accessible
        accessibilityRole="button"
        accessibilityLabel={`${dog.name}, возраст ${dog.age}`}
        accessibilityHint="Показывает или скрывает хобби собаки"
        accessibilityState={{ expanded }}
      >
        <View style={styles.info}>
          <Text style={styles.name}>{dog.name}</Text>
          <Text style={styles.age}>{`Возраст: ${dog.age}`}</Text>
        </View>
        <Text style={styles.chevron}>{expanded ? '▴' : '▾'}</Text>
      </Pressable>

      {expanded && (
        <View style={styles.hobby}>
          <Text style={styles.hobbyTitle}>Хобби</Text>
          <Text>{dog.hobby}</Text>
        </View>
      )}
    </View>
  )
}

export default function App() {
  return (
    <View style={styles.screen}>
      <Text style={styles.title}>Woof</Text>

      <FlatList
        data={dogs}
        keyExtractor={(item) => item.id}
        contentContainerStyle={styles.list}
        renderItem={({ item }) => <DogCard dog={item} />}
      />

      <StatusBar style="auto" />
    </View>
  )
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: '#F5F5F5', paddingTop: 48 },
  title: { fontSize: 24, fontWeight: 'bold', paddingHorizontal: 16, marginBottom: 8 },
  list: { padding: 16 },
  card: { backgroundColor: '#FFFFFF', borderRadius: 12, marginBottom: 16 },
  header: { flexDirection: 'row', alignItems: 'center', minHeight: 44, padding: 16 },
  info: { flex: 1 },
  name: { fontSize: 18, fontWeight: 'bold' },
  age: { color: '#555555' },
  chevron: { fontSize: 20, color: '#0057B8' },
  hobby: { paddingHorizontal: 16, paddingBottom: 16, gap: 4 },
  hobbyTitle: { fontSize: 13, color: '#555555' },
})
```

Разберём ключевые моменты:

- Заголовок карточки — единственная интерактивная зона, у неё `minHeight: 44` и метка с именем и возрастом.
- `accessibilityState={{ expanded }}` сообщает программе чтения с экрана, раскрыта карточка или нет.
- Хобби появляется только при `expanded`, поэтому тест легко отличает свёрнутое состояние от раскрытого.

## Проверка вручную: VoiceOver и TalkBack

- **TalkBack (Android):** Настройки → Специальные возможности → TalkBack → Включить.
- **VoiceOver (iPhone):** Настройки → Универсальный доступ → VoiceOver → Включить.
- Жесты: проведите пальцем вправо — следующий элемент, дважды коснитесь — активировать; список прокручивается двумя пальцами.

Пройдите приложение и проверьте:

1. Метка карточки произносится целиком: «Рекс, возраст 3, кнопка».
2. После активации озвучивается состояние и читается текст хобби.
3. Декоративная стрелка не читается отдельным элементом, все элементы идут сверху вниз.

## Автоматические тесты доступности

Установите те же библиотеки, что и в практической работе 15:

```bash
npm install --save-dev jest-expo jest @types/jest @testing-library/react-native
```

Добавьте в `package.json` команду `"test": "jest"` и пресет `"jest": { "preset": "jest-expo" }` — так же, как в практической работе 15.

Создайте файл `__tests__/App.test.tsx`. `getByLabelText` ищет элемент по `accessibilityLabel` — так же, как его находит пользователь программы чтения с экрана, а `getByRole` проверяет роль:

```tsx
import { fireEvent, render, screen } from '@testing-library/react-native'

import App from '../App'

describe('Доступность Woof', () => {
  test('карточка собаки имеет понятную метку', () => {
    render(<App />)

    expect(screen.getByLabelText('Рекс, возраст 3')).toBeTruthy()
  })

  test('карточка объявлена кнопкой с именем', () => {
    render(<App />)

    expect(screen.getByRole('button', { name: 'Рекс, возраст 3' })).toBeTruthy()
  })

  test('нажатие на карточку раскрывает хобби', () => {
    render(<App />)

    expect(screen.queryByText('Любит приносить мяч и плавать в озере.')).toBeNull()

    fireEvent.press(screen.getByLabelText('Рекс, возраст 3'))

    expect(screen.getByText('Любит приносить мяч и плавать в озере.')).toBeTruthy()
  })
})
```

Запустите тесты командой `npm test` — все три теста должны пройти. Обратите внимание: `queryByText` в отличие от `getByText` не выбрасывает ошибку, а возвращает `null`, если элемента нет, — им удобно проверять состояние до действия. Тесты используют те же метки, что слышит пользователь, поэтому переименование метки сразу заметно.

## Резюме

- Доступность делает приложение удобным для людей с разными особенностями зрения, слуха и ловкости.
- `accessibilityLabel` описывает элемент, `accessibilityRole` задаёт его роль, `accessibilityHint` объясняет действие, `accessibilityState` сообщает состояние.
- Цели нажатия делают не меньше 44 × 44 пикселей, а мелким кнопкам добавляют `hitSlop`.
- VoiceOver и TalkBack позволяют проверить приложение вручную — так же, как им пользуется реальный человек.
- `getByLabelText` и `getByRole` проверяют доступность автоматически в Jest-тестах.
