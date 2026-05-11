import { StatusBar } from 'expo-status-bar';
import { Component, ReactNode, Suspense, use, useState } from 'react';
import {
  ActivityIndicator,
  Button,
  StyleSheet,
  Text,
  View,
} from 'react-native';

type User = { id: number; name: string; email: string };

const fetchUser = async (id: number): Promise<User> => {
  await new Promise((resolve) => setTimeout(resolve, 2000)); // Simulate network delay
  const res = await fetch(`https://jsonplaceholder.typicode.com/users/${id}`);
  if (!res.ok) throw new Error(`Failed to fetch user ${id}: ${res.status}`);
  return res.json();
};

class ErrorBoundary extends Component<
  {
    fallback: (error: Error, reset: () => void) => ReactNode;
    onReset?: () => void;
    children: ReactNode;
  },
  { error: Error | null }
> {
  state = { error: null as Error | null };

  static getDerivedStateFromError(error: Error) {
    return { error };
  }

  reset = () => {
    this.setState({ error: null });
    this.props.onReset?.();
  };

  render() {
    if (this.state.error) {
      return this.props.fallback(this.state.error, this.reset);
    }
    return this.props.children;
  }
}

function UserCard({ userPromise }: { userPromise: Promise<User> }) {
  const user = use(userPromise);
  return (
    <View style={styles.card}>
      <Text style={styles.name}>{user.name}</Text>
      <Text style={styles.email}>{user.email}</Text>
      <Text style={styles.id}>user #{user.id}</Text>
    </View>
  );
}

export default function App() {
  const [id, setId] = useState(1);
  const [userPromise, setUserPromise] = useState(() => fetchUser(1));

  const loadUser = (nextId: number) => {
    setId(nextId);
    setUserPromise(fetchUser(nextId));
  };

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Suspense + use() sample</Text>

      <ErrorBoundary
        onReset={() => loadUser(1)}
        fallback={(error, reset) => (
          <View style={styles.card}>
            <Text style={styles.error}>Error: {error.message}</Text>
            <Button title="Retry" onPress={reset} />
          </View>
        )}
      >
        <Suspense fallback={<ActivityIndicator size="large" />}>
          <UserCard userPromise={userPromise} />
        </Suspense>
      </ErrorBoundary>

      <View style={styles.buttons}>
        <Button
          title="Prev"
          onPress={() => loadUser(Math.max(1, id - 1))}
          disabled={id <= 1}
        />
        <Button title="Next" onPress={() => loadUser(id + 1)} />
        <Button
          title="Force error"
          onPress={() => setUserPromise(fetchUser(99999))}
        />
      </View>

      <StatusBar style="auto" />
    </View>
  );
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
});
