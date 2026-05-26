import { StatusBar } from 'expo-status-bar'
import {
  Component,
  ReactNode,
  Suspense,
  use,
  useState,
  useTransition,
} from 'react'
import { ActivityIndicator, Button, StyleSheet, Text, View } from 'react-native'

type User = { id: number; name: string; email: string }

const fetchUser = async (id: number): Promise<User> => {
  await new Promise((resolve) => setTimeout(resolve, 2000)) // Simulate network delay
  const res = await fetch(`https://dummyjson.com/users/${id}`)
  if (!res.ok) throw new Error(`Failed to fetch user ${id}: ${res.status}`)
  const json = await res.json()
  return {
    id: json.id,
    name: `${json.firstName} ${json.lastName}`,
    email: json.email,
  }
}

class ErrorBoundary extends Component<
  {
    fallback: (error: Error, reset: () => void) => ReactNode
    onReset?: () => void
    children: ReactNode
  },
  { error: Error | null }
> {
  state = { error: null as Error | null }

  static getDerivedStateFromError(error: Error) {
    return { error }
  }

  reset = () => {
    this.setState({ error: null })
    this.props.onReset?.()
  }

  render() {
    if (this.state.error) {
      return this.props.fallback(this.state.error, this.reset)
    }
    return this.props.children
  }
}

function UserCard({ userPromise }: { userPromise: Promise<User> }) {
  const user = use(userPromise)
  return (
    <View style={styles.card}>
      <Text style={styles.name}>{user.name}</Text>
      <Text style={styles.email}>{user.email}</Text>
      <Text style={styles.id}>user #{user.id}</Text>
    </View>
  )
}

export default function App() {
  const [id, setId] = useState(1)
  const [userPromise, setUserPromise] = useState(() => fetchUser(1))
  const [isPending, startTransition] = useTransition()

  const loadUser = (nextId: number) => {
    startTransition(() => {
      setId(nextId)
      setUserPromise(fetchUser(nextId))
    })
  }

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Suspense + use() sample</Text>

      <ErrorBoundary
        onReset={() => loadUser(1)}
        fallback={(error, reset) => (
          <View style={styles.card}>
            <Text style={styles.error}>Error: {error.message}</Text>
            <Button title='Retry' onPress={reset} />
          </View>
        )}
      >
        <Suspense fallback={<ActivityIndicator size='large' />}>
          <View style={{ opacity: isPending ? 0.5 : 1 }}>
            <UserCard userPromise={userPromise} />
          </View>
        </Suspense>
      </ErrorBoundary>

      <View style={styles.buttons}>
        <Button
          title='Prev'
          onPress={() => loadUser(Math.max(1, id - 1))}
          disabled={isPending || id <= 1}
        />
        <Button
          title='Next'
          onPress={() => loadUser(id + 1)}
          disabled={isPending}
        />
        <Button
          title='Force error'
          onPress={() => {
            startTransition(() => {
              setUserPromise(fetchUser(99999))
            })
          }}
        />
      </View>

      <StatusBar style='auto' />
    </View>
  )
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 24,
    padding: 24,
  },
  title: { fontSize: 20, fontWeight: '600' },
  debug: { fontSize: 12, color: '#888', fontFamily: 'monospace' },
  card: {
    padding: 20,
    borderRadius: 12,
    backgroundColor: '#eef2ff',
    minWidth: 240,
    alignItems: 'center',
    gap: 4,
  },
  name: { fontSize: 18, fontWeight: 'bold' },
  email: { color: '#444' },
  id: { color: '#888', fontSize: 12, marginTop: 4 },
  error: { color: '#b00020', marginBottom: 8 },
  buttons: { flexDirection: 'row', gap: 12 },
})
