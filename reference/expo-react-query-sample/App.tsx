import {
  QueryClient,
  QueryClientProvider,
  QueryErrorResetBoundary,
  useSuspenseQuery,
} from '@tanstack/react-query';
import { StatusBar } from 'expo-status-bar';
import { Component, ReactNode, Suspense, useState } from 'react';
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
  const res = await fetch(`https://dummyjson.com/users/${id}`);
  if (!res.ok) throw new Error(`Failed to fetch user ${id}: ${res.status}`);
  const json = await res.json();
  return { id: json.id, name: `${json.firstName} ${json.lastName}`, email: json.email };
};

const queryClient = new QueryClient({
  defaultOptions: {
    queries: { retry: false, staleTime: 0, gcTime: 0 },
  },
});

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

function UserCard({ id }: { id: number }) {
  const { data: user } = useSuspenseQuery({
    queryKey: ['user', id] as const,
    queryFn: () => fetchUser(id),
  });
  return (
    <View style={styles.card}>
      <Text style={styles.name}>{user.name}</Text>
      <Text style={styles.email}>{user.email}</Text>
      <Text style={styles.id}>user #{user.id}</Text>
    </View>
  );
}

function UserView() {
  const [id, setId] = useState(1);

  return (
    <>
      <QueryErrorResetBoundary>
        {({ reset: resetQuery }) => (
          <ErrorBoundary
            onReset={() => {
              resetQuery();
              setId(1);
            }}
            fallback={(error, resetBoundary) => (
              <View style={styles.card}>
                <Text style={styles.error}>Error: {error.message}</Text>
                <Button title="Retry" onPress={resetBoundary} />
              </View>
            )}
          >
            <Suspense fallback={<ActivityIndicator size="large" />}>
              <UserCard id={id} />
            </Suspense>
          </ErrorBoundary>
        )}
      </QueryErrorResetBoundary>

      <View style={styles.buttons}>
        <Button
          title="Prev"
          onPress={() => setId((v) => Math.max(1, v - 1))}
          disabled={id <= 1}
        />
        <Button title="Next" onPress={() => setId((v) => v + 1)} />
        <Button title="Force error" onPress={() => setId(99999)} />
      </View>
    </>
  );
}

export default function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <View style={styles.container}>
        <Text style={styles.title}>TanStack Query + Suspense sample</Text>
        <UserView />
        <StatusBar style="auto" />
      </View>
    </QueryClientProvider>
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
